#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint background_uploader.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'background_uploader'
  s.version          = '0.0.1'
  s.summary          = 'OS-backed background file uploader for Android and Apple platforms.'
  s.description      = <<-DESC
Flutter plugin that uploads files through the OS background transfer facility
(a background URLSession on iOS and macOS) so transfers survive app suspension.
                       DESC
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files     = 'background_uploader/Sources/background_uploader/**/*'
  s.ios.dependency       'Flutter'
  s.osx.dependency       'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
