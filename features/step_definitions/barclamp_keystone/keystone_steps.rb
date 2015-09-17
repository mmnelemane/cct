Given(/^the chef role "([^"]*)" exists on admin node$/) do |arg1|
    keystone_server_role = admin_node.exec!("knife role show keystone-server").output
    expect(keystone_server_role).not_to be_empty
end

And(/^the "([^"]*)" cookbook exists on the admin node$/) do |arg1|
    keystone_cookbook = admin_node.exec!("knife cookbook show keystone").output
    expect(keystone_cookbook).not_to be_empty
end

And(/^the barclamp proposal is using the keystone identity service$/) do
    json_response = JSON.parse(admin_node.exec!("crowbar keystone show default").output)
    @node_fqdn = json_response["deployment"]["keystone"]["elements"]["keystone-server"][0]
    expect(@node_fqdn).not_to be_empty
end

When(/^the node with keystone-server role has been detected successfully$/) do
    user_list = control_node.openstack.user.list
    expect(user_list).not_to be_empty
end

And(/^the "([^"]*)" is installed in the controller node$/) do |test_package|
    control_node.rpm_q(test_package)
end

And(/^the "([^"]*)" is installed on the controller node$/) do |client_package|
    control_node.rpm_q(client_package)
end

Then(/^I can create a new project "([^"]*)" on the cloud$/) do |project_name|
    response = control_node.openstack.project.create(project_name)
    puts "Project #{response.name} created with ID: #{response.id}"
    expect(response.name).to eq(project_name)
end

And(/^I can create a new user "([^"]*)" for the "([^"]*)" project$/) do |user_name, project_name|
    response = control_node.openstack.user.create(user_name, 
                                                   project: project_name)
    puts "Created user #{response.name} on Project : #{response.project_id}"
    expect(response.name).to eq(user_name)
end

And(/^I can see the list of all available hosts on the cloud$/) do
    host_list = control_node.openstack.host.list
    puts "List of hosts available"
    host_list.each do |host|
        puts "Name: #{host.name}    Service: #{host.service}    Zone: #{host.zone}"
    end
end

And(/^I can delete the project "([^"]*)" and user "([^"]*)"$/) do |project_name, user_name|
    control_node.openstack.user.delete(user_name)
    control_node.openstack.project.delete(project_name)
end
