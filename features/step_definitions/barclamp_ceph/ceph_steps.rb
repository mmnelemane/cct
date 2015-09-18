Given(/^the barclamp proposal for ceph is deployed$/) do
  json_response = JSON.parse(admin_node.exec!("crowbar ceph show default").output)
  expect(json_response["attributes"]["ceph"]["config"]["osds_in_total"]).not_to be < 2
end

When(/^the node with ceph-mon role has been detected successfully$/) do 
  @node_list = Hash.new
  json_response = JSON.parse(admin_node.exec!("crowbar ceph show default").output)
  @node_list["ceph-mon"] = json_response["deployment"]["ceph"]["elements"]["ceph-mon"]
  expect(@node_list["ceph-mon"]).not_to be_empty
end

And(/^the node with ceph-osd role has been detected successfully$/) do 
  json_response = JSON.parse(admin_node.exec!("crowbar ceph show default").output)
  @node_list["ceph-osd"] = json_response["deployment"]["ceph"]["elements"]["ceph-osd"]
  expect(@node_list["ceph-osd"]).not_to be_empty
end

And(/^the package ceph is installed in the controller node$/) do
  node = nodes.find(fqdn: @node_list["ceph-mon"][0])
  node.exec!("rpm -q ceph")
end

Then(/^I can check that the overall health of the ceph cluster is OK$/) do
  json_response = JSON.parse(control_node.exec!("ceph status -f json-pretty").output)
  expect(json_response["health"]["overall_status"]).to eq("HEALTH_OK")
end

And(/^I can get the CRUSH tree of the ceph cluster$/) do
  json_response = JSON.parse(control_node.exec!("ceph osd tree -f json-pretty").output)
  expect(json_response).not_to be_empty
end

And(/^I can check the status of the placement groups$/) do
  response = control_node.exec!("ceph pg stat --concise").output
  expect(response).not_to be_empty
end

And(/^I can check if data, metadata and rbd have pools allocated$/) do
  json_response = JSON.parse(control_node.exec!("ceph osd lspools -f json-pretty").output)
  data_exists = metadata_exists = rbd_exists = rgw_exists = false
  json_response.each do |pool_record|
    if pool_record["poolname"] == "data"
      data_exists = true
    end
    if pool_record["poolname"] == "metadata"
      metadata_exists = true
    end
    if pool_record["poolname"] == "rbd" 
      rbd_exists = true
    end
    if pool_record["poolname"] == ".rgw"
      rgw_exists = true
    end
  end
  expect(data_exists && metadata_exists && rbd_exists && rgw_exists).to eq(true)
end

And(/^I can create a block device "([^"]*)" in the data pool$/) do |rbd_name|
  control_node.exec!("rbd create #{rbd_name} --size 1024 --pool data")
  response = control_node.exec!("rbd ls --pool data").output
  obj_list = response.split(/\n/)
  expect(obj_list).to include(rbd_name)
end

And(/^I can retreive the block device image information or resize it$/) do
  rbd_info = control_node.exec!("rbd info cucumber_rbd --pool data").output
  resize_output = control_node.exec!("rbd resize --size 2048 cucumber_rbd --pool data").output
  rbd_info = control_node.exec!("rbd info cucumber_rbd --pool data").output
  s_expect = "size 2048 MB"
  s1 = "size 1024 MB"
  rbd_info.lines.each do |line|
    if line.match(/size/)
      s1 = line.match(/size 2048 MB/)[0].to_s
    end
  end
  expect(s1).to eq(s_expect)
end

And(/^I can remove the block device "([^"]*)" in the data pool$/) do |rbd_name|
  control_node.exec!("rbd rm #{rbd_name} --pool data")
  response = control_node.exec!("rbd ls --pool data").output
  obj_list = response.split(/\n/)
  expect(obj_list).not_to include(rbd_name)
end

Given(/^the node with ceph-radosgw role has been detected successfully$/) do 
  json_response = JSON.parse(admin_node.exec!("crowbar ceph show default").output)
  @node_list["ceph-radosgw"] = json_response["deployment"]["ceph"]["elements"]["ceph-radosgw"]
  expect(@node_list["ceph-radosgw"]).not_to be_empty
end

And(/^the package ceph-radosgw is installed in the controller node$/) do
  node = nodes.find(fqdn: @node_list["ceph-radosgw"][0])
  node.exec!("rpm -q ceph-radosgw")
end

Then(/^I can create a radosgw-admin user "([^"]*)"$/) do |rgw_username|
  json_response = JSON.parse(control_node.exec!("radosgw-admin user create --display-name=\"cucumber test\" --uid=cucumber").output)
  expect(json_response["user_id"]).to eq("cucumber")
end

And(/^I can remove radosgw-admin user "([^"]*)"$/) do |rgw_username|
  control_node.exec!("radosgw-admin user rm --uid=cucumber")
end

And(/^I can create an object "([^"]*)" in the "([^"]*)" pool and see the object in the list$/) do |obj_name, pool_name|
  control_node.exec!("rados create #{obj_name} --pool #{pool_name}")
  response = control_node.exec!("rados ls --pool #{pool_name}").output
  obj_list = response.split(/\n/)
  expect(obj_list).to include(obj_name)
end

And(/^I can download the object "([^"]*)" into the file system$/) do |obj_name|
  control_node.exec!("rados get #{obj_name} cucumber.obj --pool data")
  response = control_node.exec!("ls cucumber.obj").output
  obj_list = response.split(/\n/)
  expect(obj_list).to include("cucumber.obj")
end

And(/^I can delete the object "([^"]*)" from the data pool$/) do |obj_name|
  control_node.exec!("rados rm #{obj_name} --pool data")
  response = control_node.exec!("rados ls --pool data").output
  obj_list = response.split(/\n/)
  expect(obj_list).not_to include(obj_name)
end
