Pod::Spec.new do |s|
  s.name             = 'ensemble_app_badger'
  s.version          = '1.6.0'
  s.summary          = 'Plugin to update the app badge on the launcher (both for Android, iOS and macOS)'
  s.description      = <<-DESC
  Plugin to update the app badge on the launcher (both for Android, iOS and macOS)
                       DESC
  s.homepage         = 'https://github.com/EnsembleUI/flutter_app_badger'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'EnsembleUI'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'FlutterMacOS'

  s.platform = :osx
  s.osx.deployment_target = '10.11'
end