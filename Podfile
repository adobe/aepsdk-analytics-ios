# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'
use_frameworks!

project 'AEPAnalytics.xcodeproj'

target 'AEPAnalytics' do
  pod 'AEPCore'
  pod 'AEPServices'
  pod 'AEPIdentity'
  pod 'AEPRulesEngine'
end

target 'AEPAnalyticsTests' do
  pod 'AEPCore'
  pod 'AEPServices'
  pod 'AEPIdentity'
  pod 'AEPRulesEngine'
end

target 'AnalyticsSampleApp' do
  pod 'AEPCore'
  pod 'AEPServices'
  pod 'AEPIdentity'
  pod 'AEPRulesEngine'
  pod 'ACPCore', :git => 'https://github.com/adobe/aepsdk-compatibility-ios.git', :branch => 'main'
  pod 'AEPAssurance'
end
