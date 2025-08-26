#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ensemble_otp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ensemble_otp'
  s.version          = '1.0.2'
  s.summary          = 'A beautiful and highly customizable Flutter widget for OTP and PIN code input fields.'
  s.description      = <<-DESC
A beautiful and highly customizable Flutter widget for OTP and PIN code input fields. Features include beautiful animations, custom styling, SMS autofill, custom keyboards, and extensive customization options. Perfect for authentication flows, verification screens, and any application requiring secure PIN or OTP input.
                       DESC

  s.homepage         = 'https://ensembleui.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ensemble UI' => 'info@ensembleui.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'ensemble_otp-Swift.h'
  }
  s.swift_version = '5.0'
end
