#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'ensemble_agent'
  s.version          = '0.1.0'
  s.summary          = 'On-device AI agent runtime for Flutter.'
  s.description      = <<-DESC
Provider-independent Flutter runtime for on-device AI agents with Apple
Foundation Models integration on iOS.
                       DESC
  s.homepage         = 'https://ensembleui.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ensemble UI' => 'info@ensembleui.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'ensemble_agent-Swift.h'
  }
  s.swift_version = '5.0'
end
