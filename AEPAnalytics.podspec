Pod::Spec.new do |s|
  s.name             = "AEPAnalytics"
  s.version          = "3.2.0"
  s.summary          = "Analytics library for Adobe Experience Platform SDK. Written and maintained by Adobe."
  s.description      = <<-DESC
                        The Analytics library provides APIs that allow use of the Analytics product in the Adobe Experience Platform SDK.
                        DESC
  s.homepage         = "https://github.com/adobe/aepsdk-analytics-ios"
  s.license          = 'Apache V2'
  s.author       = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aepsdk-analytics-ios", :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

  s.dependency 'AEPCore', '>= 3.7.0'
  s.dependency 'AEPServices', '>= 3.7.0'

  s.source_files          = 'AEPAnalytics/Sources/*.swift'


end
