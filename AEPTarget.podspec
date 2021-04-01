Pod::Spec.new do |s|
  s.name             = "AEPTarget"
  s.version          = "3.0.0"
  s.summary          = "Experience Platform Target extension for Adobe Experience Platform Mobile SDK. Written and maintained by Adobe."
  s.description      = <<-DESC
                        The Experience Platform Target extension provides APIs that allow use of the Target product in the Adobe Experience Platform SDK.
                        DESC
  s.homepage         = "https://github.com/adobe/aepsdk-target-ios"
  s.license          = 'Apache V2'
  s.author       = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aepsdk-target-ios.git", :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.1'
  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }
  s.dependency 'AEPCore', ">= 3.1.0"

  s.source_files          = 'AEPTarget/Sources/**/*.swift'

end
