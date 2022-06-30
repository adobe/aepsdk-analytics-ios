# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'
use_frameworks!

project 'AEPAnalytics.xcodeproj'

pod 'SwiftLint', '0.44.0'

def core_pods
  pod 'AEPServices'
  pod 'AEPCore'
  pod 'AEPRulesEngine'
end

def test_pods
  pod 'AEPServices'
  pod 'AEPCore'
  pod 'AEPLifecycle'
  pod 'AEPIdentity'
end

target 'AEPAnalytics' do
  core_pods
end

target 'UnitTests' do
  core_pods
end

target 'FunctionalTests' do
  core_pods
end

target 'TestAppiOS' do
  test_pods
  pod 'AEPAssurance', '~> 3.0.0'
end

target 'TestAppExt' do
  test_pods
end

target 'TestApptvOS' do
  test_pods
end

post_install do |pi|
  pi.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
        bc.build_settings['TVOS_DEPLOYMENT_TARGET'] = '10.0'
        bc.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator appletvos appletvsimulator'
        bc.build_settings['TARGETED_DEVICE_FAMILY'] = "1,2,3"
    end
  end
end
