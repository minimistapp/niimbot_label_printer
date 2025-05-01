#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint niimbot_label_printer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'niimbot'
  s.version          = '0.0.2'
  s.summary          = 'Niimbot Label Printer SDK'
  s.description      = <<-DESC
Niimbot Label Printer SDK
                       DESC
  s.homepage         = 'https://mnm.st'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Henrik Feldt' => 'henrik@mnm.st' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
