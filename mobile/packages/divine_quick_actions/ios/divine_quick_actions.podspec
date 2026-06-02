#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint divine_quick_actions.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'divine_quick_actions'
  s.version          = '0.0.1'
  s.summary          = 'Quick Actions plugin for Android and iOS.'
  s.description      = <<-DESC
Flutter plugin providing typed iOS home-screen quick actions.
                       DESC
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'divine_quick_actions_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
