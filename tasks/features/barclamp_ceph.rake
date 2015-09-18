namespace :feature do
  feature_name "Tests Ceph barclamp deployment"

  namespace :barclamp do
    desc "Barclamp Ceph feature"
    namespace :ceph do
      desc "Test Ceph block device deployment"
      feature_task :rbd, tags: :@ceph

      desc "Test Ceph RadowGW deployment"
      feature_task :radosgw, tags: :@radosgw

      feature_task :all
    end
    desc "Verification of Ceph Deployment"
    task :ceph => "ceph:all"
  end
end
