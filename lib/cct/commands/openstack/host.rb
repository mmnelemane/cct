module Cct
  module Commands
    module Openstack
      class Host < Command
        self.command = "host"

        def list *options
          super(*(options << {row: Struct.new(:name, :service, :zone)}))
        end
      end
    end
  end
end
