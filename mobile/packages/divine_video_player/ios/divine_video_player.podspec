Pod::Spec.new do |s|
  s.name             = 'divine_video_player'
  s.version          = '0.1.0'
  s.summary          = 'Multi-clip seamless video player for iOS.'
  s.description      = 'Multi-clip video player using AVFoundation.'
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Divine Video' => 'dev@divinevideo.co' }
  s.source           = { :http => 'https://github.com/divinevideo/divine-mobile' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
