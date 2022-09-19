source 'https://cdn.cocoapods.org/'
source 'https://github.com/FutureWorkshops/MWPodspecs.git'

workspace 'MWAppAuth'
platform :ios, '15.0'

inhibit_all_warnings!
use_frameworks!

project 'MWAppAuth/MWAppAuth.xcodeproj'
project 'MWAppAuthPlugin/MWAuthPlugin.xcodeproj'

abstract_target 'MWAppAuth' do
  pod 'MobileWorkflow'
  pod 'AppAuth', '~> 1.4.0'

  target 'MWAppAuth' do
    project 'MWAppAuth/MWAppAuth.xcodeproj'

    target 'MWAppAuthTests' do
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
