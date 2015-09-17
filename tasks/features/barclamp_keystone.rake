namespace :feature do
  feature_name "Tests Openstack Keystone barclamp"

  namespace :barclamp do
    desc "Barclamp Keystone feature"
    feature_task :keystone, tags: :@keystone

    desc "Verification of 'Tests Openstack Keystone barclamp' feature"
    feature_task :all
  end
end
