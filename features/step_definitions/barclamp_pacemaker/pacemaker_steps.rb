# 
# Function to identify primary and secondary nodes from the list of available
# nodes.
#
def _get_primary_secondary_nodes 
  primary_node = nil
  secondary_node = nil

  node_list = admin_node.exec!("crowbar pacemaker element_node pacemaker-cluster-member list").output.split(/\n/)
  node_list.each do |node_fqdn|
    node = nodes.find(fqdn: node_fqdn).first
    drbd_role = node.exec!("drbdadm role all", capture_error: true)
    if drbd_role.success?
      dev_priority = drbd_role.output.split(/\n/).first
      if dev_priority == "Primary/Secondary"
        primary_node = nodes.find(fqdn: node_fqdn).first
      elsif dev_priority == "Secondary/Primary"
        secondary_node = nodes.find(fqdn: node_fqdn).first
      end
    else
      results = node.exec!("crmadmin --dc_lookup", capture_error: true)
      if results.success? 
        if results.output.include?("Designated Controller")
          result_name = results.output.split(/:/)[-1].strip!
          primary_node = nodes.find(name: result_name).first
        else
          secondary_node = nodes.find(fqdn: node_fqdn).first
        end
      end
    end
  end
  return primary_node, secondary_node
end

#=====================================
# Steps for packages and initial setup
# ====================================
Given(/^the barclamp proposal for "([^"]*)" is deployed$/) do |package_name|
  response = admin_node.exec!("crowbar #{package_name} list").output
  @node_list = response.strip!.split(/\n/)
  expect(@node_list).not_to be_empty
end

And(/^the relevant chef roles for pacemaker configs exists on admin node$/) do
  @node_list.each do |node_type|
    admin_node.exec!("knife role show pacemaker-config-#{node_type}")
  end
end

When(/^the node with "([^"]*)" role has been detected successfully$/) do |role_name|
  @node_list.each do |node_name|
    json_response = JSON.parse(admin_node.exec!("crowbar pacemaker show #{node_name}").output)
    node_elements = nodes.find(barclamp: "pacemaker", element: "#{role_name}", proposal: "#{node_name}")
    expect(node_elements).not_to be_empty
  end
end

When(/^the package "([^"]*)" is installed in the cluster node$/) do |package_name|
  @node_list.each do |node_name|
    node_elements = nodes.find(barclamp: "pacemaker", element: "pacemaker-cluster-member", proposal: "#{node_name}").map do |node|
      node.rpm_q(package_name)
    end
    node_elements
  end
end


#===============================
# Steps specific DRBD deployment
# ==============================

def is_drbd()
  node_elements = nodes.find(barclamp: "pacemaker", element: "pacemaker-cluster-member", proposal: "data").map do |node|
    node.rpm_q("drbd")
  end
  if !node_elements.empty?
    return true
  else
    return false
  end
end
  
Given(/^the chef role for pacemaker-config-data exists on the admin node$/) do
  admin_node.exec!("knife role show pacemaker-config-data")
end

And(/^the package drbd is installed in the cluster node$/) do
  expect(is_drbd()).to eq(true) 
end

Then(/^I can identify the primary and secondary nodes for the drbd cluster$/) do
  @primary_node , @secondary_node = _get_primary_secondary_nodes()
  expect(@primary_node.attributes()[:name]).not_to be_empty
  expect(@secondary_node.attributes()[:name]).not_to be_empty
end

And(/^I can ensure both primary and secondary nodes of drbd are UpToDate$/) do
  if is_drbd()
    response = @primary_node.exec!("drbdadm dstate rabbitmq").output
    expect(response.strip!).to eq("UpToDate/UpToDate")
    response = @primary_node.exec!("drbdadm dstate postgresql").output
    expect(response.strip!).to eq("UpToDate/UpToDate")
  end
end

And(/^I can get a valid GI value for all resources$/) do
  if is_drbd()
    @primary_node.exec!("drbdadm get-gi all")
    @secondary_node.exec!("drbdadm get-gi all")
  end
end

And(/^I can verify the location of rabbitmq and postgresql resources$/) do
  if is_drbd()
    response = @primary_node.exec!("crm_resource --resource drbd-rabbitmq --locate").output
    location = response.split(/:/)[-1].split(/ /).reject{ |c| c.empty?}[0]
    exp_location = ["#{@primary_node.attributes()[:name]}", "#{@secondary_node.attributes()[:name]}"]
    expect(exp_location).to include(location)
    response = @primary_node.exec!("crm_resource --resource drbd-postgresql --locate").output
    location = response.split(/:/)[-1].split(/ /).reject{ |c| c.empty?}[0]
    expect(exp_location).to include(location)
  end
end

And(/^I can get the mountpoints for devices "drbd0" and "drbd1"$/) do
  if is_drbd()
    response = @primary_node.exec!("mount | grep drbd").output
    mount_lines = response.split(/\n/)
    mount_lines.each do |line|
      drbd_dev = line.split(/ /)[0]
      mount_pt = line.split(/ /)[2]
      expect(mount_pt).not_to be_empty
    end
  end
end

#==========================
# Steps for Stonith Device
# =========================
Given(/^I can identify the primary and secondary nodes for the stonith cluster$/) do
  @primary_node , @secondary_node = _get_primary_secondary_nodes()
  expect(@primary_node.attributes()[:name]).not_to be_empty
  expect(@secondary_node.attributes()[:name]).not_to be_empty
end

And(/^the cluster is configured with stonith-enabled$/) do
  response = @primary_node.exec!("crm configure show type:property").output
  expect(response).not_to be_empty
end

Then(/^I can list the available stonith devices$/) do
  response = @primary_node.exec!("stonith_admin --list-registered").output
  @stonith_device = response.split(/\n/)[0].strip!
  expect(@stonith_device).to eq("stonith-#{@secondary_node.attributes()[:name]}")
end

And(/^I can obtain metadata for an arbitrary fencing agent$/) do
  response = @primary_node.exec!("stonith_admin -M #{@stonith_device} --agent fence_pcmk").output
  expect(response).not_to be_empty
end

And(/^I can check the failcount of stonith resources$/) do
  response = @primary_node.exec!("crm_failcount --resource-id=rabbitmq").output
  fail_count = response.tr("\n", "").split(/ /)[-1]
  expect(fail_count).to eq("value=0")
end

#=============================
# Steps specific to CRM tests
# ============================
Given(/^There are valid pacemaker cluster nodes deployed successfully$/) do
  @element_nodes = admin_node.exec!("crowbar pacemaker element_node pacemaker-cluster-member").output.split(/\n/)
  expect(@element_nodes).not_to be_empty
end

And(/^I can identify the primary and secondary nodes for the crm cluster$/) do
  @primary_node , @secondary_node = _get_primary_secondary_nodes()
  expect(@primary_node.attributes()[:name]).not_to be_empty
  expect(@secondary_node.attributes()[:name]).not_to be_empty
end

Then(/^I can check if the status of all crm nodes are ok$/) do
  response = @primary_node.exec!("crmadmin --nodes").output
  node_list = response.split(/\n/).reject { |c| c.empty?}
  exp_states = ["S_IDLE (ok)", "S_NOT_DC (ok)"]
  node_list.each do |node_entry|
    node_name = node_entry.split(/ /)[3].strip!
    stat_response = @primary_node.exec!("crmadmin --status=#{node_name}").output
    node_state = stat_response.split(/:/)[1].strip!
    expect(exp_states).to include(node_state)
  end
end

And(/^I can ensure that start operations for haproxy, rabbitmq, postgresql are complete$/) do
  def get_node_resource_operations_status(node_to_check, resource_name)
    response = @primary_node.exec!("crm_resource --list-operations --resource #{resource_name} --node #{node_to_check}").output
    status = response.tr("\n","").split(/ /)[-1]
    return status
  end
  prim_node_name = @primary_node.attributes()[:name]
  expect(get_node_resource_operations_status(prim_node_name, "haproxy")).to eq("complete")
  expect(get_node_resource_operations_status(prim_node_name, "rabbitmq")).to eq("complete")
  expect(get_node_resource_operations_status(prim_node_name, "postgresql")).to eq("complete")
end

And(/^I can update and delete new attribute to a crm node$/) do
  @primary_node.exec!("crm_attribute --node d52-54-01-77-77-01 --name location --update office")
  @primary_node.exec!("crm_attribute --node d52-54-01-77-77-01 --name location --query")
  @primary_node.exec!("crm_attribute --node d52-54-01-77-77-01 --name location --delete")
end

And(/^I can verify the status of corosync being active with no faults and correct ring addresses$/) do
  # Method to obtain Corosync ring status of a node in the cluster
  def get_corosync_ring_status(node)
    # Get ring status from the node
    ring_addr = ""
    ring_status = ""
    response = node.exec!("crm corosync status").output
    lines = response.tr("\t", " ").split(/\n/)
    lines.each do |line|
      if line.include?("id =")
        ring_addr = line.split(/=/)[-1].strip!
      end
      if line.include?("status =")
        ring_status = line.split(/=/)[-1].strip!
      end
    end
    return ring_addr, ring_status
  end

  prim_ring_addr = ""
  prim_status = ""
  sec_ring_addr = ""
  sec_status = ""
   
  # Get ring address from node configuration
  response = @primary_node.exec!("crm corosync get nodelist.node.ring0_addr").output
  ring_addr_conf = response.split(/\n/)

  # Get ring status from primary node
  prim_ring_addr, prim_ring_status = get_corosync_ring_status(@primary_node)
  sec_ring_addr, sec_ring_status = get_corosync_ring_status(@secondary_node)
  expect(ring_addr_conf).to include(prim_ring_addr, sec_ring_addr)
  expect(prim_ring_status).to eq("ring 0 active with no faults")
  expect(sec_ring_status).to eq("ring 0 active with no faults")
end

And(/^I can move a cluster node to standby and back to online without affecting resources$/) do
  # Method to return list of nodes in cluster in Standby and Online Mode
  def return_standby_online_nodes (node)
    response = node.exec!("crm_mon -1").output
    lines = response.split(/\n/)
    online_nodes = []
    standby_nodes = []
    lines.each do |line|
      if line.include?("standby")
        standby_nodes = [line.split(/ /)[1]]
      elsif line.include?("Online:")
        online_nodes = line.split(/:/)[-1].delete("[]").split(/ /).reject{ |c| c.empty?}
      end
    end
    return online_nodes, standby_nodes
  end 
  
  @primary_node.exec!("crm node standby")
  online_nodes, standby_nodes = return_standby_online_nodes(@primary_node)
  expect(online_nodes).to include(@secondary_node.attributes()[:name])
  expect(standby_nodes).to include(@primary_node.attributes()[:name])
  @primary_node.exec!("crm node online")
  online_nodes, standby_nodes = return_standby_online_nodes(@primary_node)
  expect(online_nodes).to include(@primary_node.attributes()[:name], @secondary_node.attributes()[:name])
  expect(standby_nodes).to be_empty
end

And(/^I can run a cluster health check on the cluster$/) do
  response = @primary_node.exec!("crm cluster health").output
end

