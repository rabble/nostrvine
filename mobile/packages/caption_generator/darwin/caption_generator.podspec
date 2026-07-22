#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint caption_generator.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'caption_generator'
  s.version          = '0.0.1'
  s.summary          = 'On-device speech-to-text closed caption generation.'
  s.description      = <<-DESC
Flutter plugin that transcribes audio files into timed caption segments using
the on-device SFSpeechRecognizer on iOS and macOS.
                       DESC
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files     = 'caption_generator/Sources/caption_generator/**/*'
  s.ios.dependency       'Flutter'
  s.osx.dependency       'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version    = '5.9'
  s.frameworks       = 'Speech'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
