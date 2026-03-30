Pod::Spec.new do |s|
  s.name             = 'image_metadata_stripper'
  s.version          = '0.0.1'
  s.summary          = 'Strips EXIF metadata from images.'
  s.description      = <<-DESC
Strips EXIF metadata (GPS, device info, timestamps) from image files
using native NSImage/CGImage decode/re-encode.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
