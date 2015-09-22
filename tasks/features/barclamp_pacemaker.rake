namespace :feature do
  feature_name "Tests Pacemaker barclamp deployment"

  namespace :barclamp do
    desc "Barclamp Pacemaker feature"
    namespace :pacemaker do
      desc "Check Package Installations"
      feature_task :packages, tags: :@packages

      desc "Test DRBD Features"
      feature_task :drbd, tags: :@drbd

      desc "Test CRM Features"
      feature_task :crm, tags: :@crm

      desc "Test Stonith device"
      feature_task :stonith, tags: :@stonith

      feature_task :all   
    end

    desc "Verification of Pacemaker Cluster Deployment"
    task :pacemaker => "pacemaker:all"
  end
end
