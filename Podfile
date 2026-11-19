# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

# Comment the next line if you don't want to use dynamic frameworks
use_frameworks!

$dev_repo = 'https://github.com/adobe/aepsdk-core-ios.git'
$dev_branch = 'staging'

workspace 'AEPTarget'
project 'AEPTarget.xcodeproj'

pod 'SwiftLint', '0.52.0'

# ==================
# SHARED POD GROUPS
# ==================
def lib_main
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'AEPRulesEngine'
end

def lib_dev
    pod 'AEPCore', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPServices', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPRulesEngine', :git => 'https://github.com/adobe/aepsdk-rulesengine-ios.git', :branch => $dev_branch
end

def app_main
    lib_main    
    pod 'AEPIdentity'
    pod 'AEPLifecycle'
    pod 'AEPSignal'
    pod 'AEPAnalytics', :git => 'https://github.com/adobe/aepsdk-analytics-ios.git', :branch => $dev_branch
#    pod 'AEPAssurance'
end

def app_dev
    lib_dev    
    pod 'AEPIdentity', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPLifecycle', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPSignal', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPAnalytics'
    pod 'AEPAssurance', :git => 'https://github.com/adobe/aepsdk-assurance-ios.git', :branch => $dev_branch
end

# ==================
# TARGET DEFINITIONS
# ==================
target 'AEPTarget' do
  lib_main
end

target 'AEPTargetDemoApp' do
  app_main
end
  
target 'AEPTargetDemoObjCApp' do
  app_main
end

target 'AEPTargetTests' do
  app_main
  pod 'SwiftyJSON', '~> 5.0'
end

post_install do |pi|
  pi.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
      bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
