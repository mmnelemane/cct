@pacemaker
Feature: Tests Pacemaker barclamp deployment
    As an administrator
    I want to make sure the pacemaker cluster is deployed successfully
    And I can perform few operations on the components of the pacemaker cluster

  Background:
    Given the chef role "pacemaker-cluster-member" exists on admin node
    And the chef role "hawk-server" exists on admin node
    And the "pacemaker" cookbook exists on the admin node

  @packages
  Scenario: Verify packages required for pacemaker deployment
    Given the barclamp proposal for "pacemaker" is deployed
    And the relevant chef roles for pacemaker configs exists on admin node
    When the node with "pacemaker-cluster-member" role has been detected successfully
    And the node with "hawk-server" role has been detected successfully
    And the package "pacemaker" is installed in the cluster node
    And the package "corosync" is installed in the cluster node
    And the package "hawk" is installed in the cluster node

  @drbd
  Scenario: Verify functionality of DRBD deployment of rabbitmq and postgresql
    Given the chef role for pacemaker-config-data exists on the admin node
    And the package drbd is installed in the cluster node
    Then I can identify the primary and secondary nodes for the drbd cluster
    And I can ensure both primary and secondary nodes of drbd are UpToDate
    And I can get a valid GI value for all resources
    And I can verify the location of rabbitmq and postgresql resources
    And I can get the mountpoints for devices "drbd0" and "drbd1"

  @stonith
  Scenario: Verify if stonith based fencing is deployed and enabled
    Given There are valid pacemaker cluster nodes deployed successfully
    And I can identify the primary and secondary nodes for the stonith cluster
    When the cluster is configured with stonith-enabled
    Then I can list the available stonith devices
    And I can obtain metadata for an arbitrary fencing agent
    And I can check the failcount of stonith resources

  @crm
  Scenario: Verify Cluster Resource Manager features of deployed cluster
    Given There are valid pacemaker cluster nodes deployed successfully
    And I can identify the primary and secondary nodes for the crm cluster
    Then I can check if the status of all crm nodes are ok
    And I can ensure that start operations for haproxy, rabbitmq, postgresql are complete
    And I can update and delete new attribute to a crm node
    And I can verify the status of corosync being active with no faults and correct ring addresses
    And I can move a cluster node to standby and back to online without affecting resources
    And I can run a cluster health check on the cluster

