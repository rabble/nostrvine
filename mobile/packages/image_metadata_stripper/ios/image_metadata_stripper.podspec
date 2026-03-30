Pod::Spec.new do |s|
  s.name             = 'image_metadata_stripper'
  s.version          = '0.0.1'
  s.summary          = 'Strips EXIF metadata from images.'
  s.description      = <<-DESC
Strips EXIF metadata (GPS, device info, timestamps) from image files
using native UIImage decode/re-encode.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
