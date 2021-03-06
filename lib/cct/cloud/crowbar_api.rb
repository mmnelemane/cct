module Cct
  class CrowbarApi
    LOG_TAG   = "CROWBAR"
    MIME_TYPE = "application/json"

    ROUTES = {
      nodes:     "/nodes",
      barclamps: "/crowbar",
      dashboard: "/dashboard"
    }

    # Creates methods from the ROUTES.keys above
    ROUTES.each_pair do |route, fragment|
      define_method(route) { get(fragment).body }
    end

    extend Forwardable

    def_delegators :@connection, :head, :get

    attr_reader :connection, :log

    def initialize options={}
      @log = BaseLogger.new(LOG_TAG)
      config = options["api"].dup.merge!("ip" => options["ip"])
      url =
        if Cct.config.fetch("proxy")
          forward_crowbar_http(config)
        else
          use_direct_crowbar_data(config)
        end

      @connection = Faraday.new(url: url) do |builder|
        builder.request  :url_encoded
        builder.request  :digest, config['user'], config['password']
        builder.request  :json
        builder.response :crowbar_logger, log
        builder.response :json, :content_type => /\bjson$/
        builder.adapter  ::Faraday.default_adapter
      end
    rescue Faraday::ConnectionFailed => e
      raise CrowbarApiError, e.message
    end

    def actions
      public_methods.sort - Object.methods
    end

    def route name
      ROUTES[name]
    end

    def routes
      ROUTES
    end

    def node name
      get("#{route(:nodes)}/#{name}").body
    end

    def test!
      if !head.success?
        log.error "HEAD request at #{connection.build_url} failed"
        raise CrowbarApiError, "Crowbar API head request to #{connection.build_url} failed"
      end
      true
    rescue Faraday::ConnectionFailed => e
      log.error(e.message)
      raise CrowbarApiError, e.message
    end

    private

    def forward_crowbar_http api
      proxy = Cct.config.fetch("proxy")
      proxy_options = {}
      proxy_options.merge!(password: proxy["password"]) if proxy["password"]
      forward_options = [api["port"], api["ip"], api["port"]]
      forward_options.unshift(proxy["bind"]) if proxy["bind"]
      Thread.new do
        Net::SSH.start(proxy["fqdn"] || proxy["ip"], proxy["user"], proxy_options) do |ssh|
          ssh.forward.local(*forward_options)
          ssh.loop { true }
        end
      end
      sleep 0.5
      "#{api_scheme(api["ssl"])}localhost:#{api['port']}"
    end

    def api_scheme ssl
       ssl ? "https://" : "http://"
    end

    def use_direct_crowbar_data config
      api_scheme(config["ssl"]) << config["ip"] << ":#{config["port"]}"
    end
  end

  # Idea stolen from https://github.com/envylabs/faraday-detailed_logger
  # The goal is to have detailed log about sent and received data
  # If verbose all headers with response body will be logged; this might
  # be a huge amount of data as crowbar API returns a lot of details for nodes
  class CrowbarLoggerMiddleware < Faraday::Response::Middleware
    attr_reader :logger

    def initialize app, logger
      super(app)
      @logger = logger
    end

    def call env
      logger.info("#{env[:method].upcase} #{env[:url]}")
      logger.debug(curl_output(env[:request_headers], env[:body]).inspect)
      accept_json(env) #FIXME: hook to set the request headers correctly
      super
    end

    def on_complete env
      logger.info("HTTP #{env[:response_headers]["status"]}")
      logger.debug(curl_output(env[:response_headers], env[:body]).inspect)
    end

    private

    def curl_output headers, body
      string = headers.collect { |k,v| "#{k}: #{v}" }.join("\n")
      string + "\n\n#{body}"
    end

    def accept_json env
      env[:request_headers]["Accept"] = CrowbarApi::MIME_TYPE
    end
  end

  #TODO: Replace the upstream faraday json middlware
  #      This currently fails at 401 response that is not a json data
  class CrowbarJsonMiddleware < Faraday::Response::Middleware
    BRACKETS   = %w- [ { -
    WHITESPACE = [ " ", "\n", "\r", "\t" ]

    def initialize app
      super(app)
    end

    def call env
      accept_json(env)
      body_to_json(env)
      super
    end

    def on_complete env
      env[:body] = validate_body!(env)
    end

    private

    def validate_body! env
      ::JSON.parse(env[:body])
    rescue JSON::ParserError => e
      raise CrowbarApiError, "Invalid json data, " + e.message + " Url: #{env[:url]}"
    end

    def body_to_json env
      if env[:body] && !env[:body].empty? && env[:body].respond_to?(:to_str)
        env[:body] = ::JSON.dump(env[:body])
      end
    end

    def accept_json env
      env[:request_headers]["Accept"] = CrowbarApi::MIME_TYPE
    end
  end

  Faraday::Response.register_middleware(
    :crowbar_logger => CrowbarLoggerMiddleware,
    :crowbar_json   => CrowbarJsonMiddleware
  )
end
