@keystone
Feature: Tests Openstack Keystone barclamp
  As an actor
  I want to perform various validations
  In order to verify the feature functionality

  Background:
    Given the chef role "keystone-server" exists on admin node
    And the "keystone" cookbook exists on the admin node

  Scenario: Keystone deployment and functioning
    Given the barclamp proposal is using the keystone identity service
    When the node with keystone-server role has been detected successfully
    And the "python-keystone" is installed in the controller node
    And the "python-openstackclient" is installed in the controller node
    Then I can create a new project "cucumber_test" on the cloud 
    And I can create a new user "cucumber_user" for the "cucumber_test" project
    And I can see the list of all available hosts on the cloud
    And I can delete the project "cucumber_test" and user "cucumber_user"
    

