@ceph
Feature: Tests Ceph barclamp deployment
  As an administrator
  I want to make sure the ceph cluster is deployed successfully
  In order to be used by the cloud for block/object storage

  Background:
    Given the chef role "ceph-mon" exists on admin node
    And the chef role "ceph-mds" exists on admin node
    And the chef role "ceph-osd" exists on admin node
    And the chef role "ceph-radosgw" exists on admin node
    And the chef role "ceph-calamari" exists on admin node
    And the "ceph" cookbook exists on the admin node

  @rbd
  Scenario: Tests for Ceph Block Device deployment
    Given the barclamp proposal for ceph is deployed
    When the node with ceph-mon role has been detected successfully
    And the node with ceph-osd role has been detected successfully
    And the package ceph is installed in the controller node
    Then I can check that the overall health of the ceph cluster is OK
    And I can get the CRUSH tree of the ceph cluster
    And I can check the status of the placement groups
    And I can check if data, metadata and rbd have pools allocated
    And I can create a block device "cucumber_rbd" in the data pool
    And I can retreive the block device image information or resize it
    And I can remove the block device "cucumber_rbd" in the data pool

  @radosgw
  Scenario: Tests for Ceph Rados Gateway deployment
    Given the node with ceph-radosgw role has been detected successfully
    And the package ceph-radosgw is installed in the controller node
    Then I can create a radosgw-admin user "cucumber_test"
    And I can remove radosgw-admin user "cucumber_test"
    And I can create an object "cucumber_obj" in the "data" pool and see the object in the list
    And I can download the object "cucumber_obj" into the file system
    And I can delete the object "cucumber_obj" from the data pool
