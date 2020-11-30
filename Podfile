source 'https://cdn.cocoapods.org/'
source 'https://github.com/FutureWorkshops/FWTPodspecs.git'

workspace 'MobileWorkflowAppAuth'
platform :ios, '13.0'

inhibit_all_warnings!
use_frameworks!

project 'MobileWorkflowAppAuth/MobileWorkflowAppAuth.xcodeproj'
project 'MWAppAuthPlugin/MWAuthPlugin.xcodeproj'

abstract_target 'MWAppAuth' do
  pod 'MobileWorkflow'
  pod 'AppAuth'

  target 'MobileWorkflowAppAuth' do
    project 'MobileWorkflowAppAuth/MobileWorkflowAppAuth.xcodeproj'

    target 'MobileWorkflowAppAuthTests' do
      inherit! :search_paths
    end
  end

  target 'MWAppAuthPlugin' do
    project 'MWAppAuthPlugin/MWAppAuthPlugin.xcodeproj'

    target 'MWAppAuthPluginTests' do
      inherit! :search_paths
    end
  end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ""
    end
  end
end
