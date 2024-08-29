Pod::Spec.new do |s|
    s.name                  = 'MWAppAuthPlugin'
    s.version               = '0.3.6'
    s.summary               = 'AppAuth plugin for MobileWorkflow on iOS.'
    s.description           = <<-DESC
    OAuth plugin for MobileWorkflow on iOS, based on AppAuth-iOS: https://github.com/openid/AppAuth-iOS
    DESC
    s.homepage              = 'https://www.mobileworkflow.io'
    s.license               = { :type => 'Copyright', :file => 'LICENSE' }
    s.author                = { 'Future Workshops' => 'info@futureworkshops.com' }
    s.source                = { :git => 'https://github.com/FutureWorkshops/MWAppAuthPlugin-iOS.git', :tag => "#{s.version}" }
    s.platform              = :ios
    s.swift_version         = '5'
    s.ios.deployment_target = '15.0'
	s.default_subspecs      = 'Core'
	
    s.subspec 'Core' do |cs|
      cs.dependency            'MobileWorkflow', '~> 2.1.12'
      cs.source_files          = 'MWAppAuthPlugin/MWAppAuthPlugin/**/*.swift'
    end
end
