#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_share_receiver'
  s.version          = '1.0.3'
  s.summary          = 'A flutter plugin that enables flutter apps to receive sharing photos, videos, text, urls or any other file types from another app.'
  s.description      = <<-DESC
A flutter plugin that enables flutter apps to receive sharing photos, videos, text, urls or any other file types from another app.
                       DESC
  s.homepage         = 'https://github.com/EnsembleUI/flutter_share_receiver'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'EnsembleUI' => 'info@ensembleui.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '12.0'
end

