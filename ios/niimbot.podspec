Pod::Spec.new do |s|
  s.name             = 'niimbot'
  s.version          = '0.0.3'
  s.summary          = 'Niimbot Label Printer SDK for Flutter.'
  s.description      = <<-DESC
A Flutter plugin to interact with Niimbot label printers using the native iOS SDK.
                       DESC
  s.homepage         = 'https://mnm.st'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Henrik Feldt' => 'henrik@mnm.st' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # The SDK headers themselves are part of the module defined by the module map.
  # They don't need to be public_header_files of the `niimbot` swift module.
  # s.public_header_files = 'Headers/JCAPI.h', 'Headers/JCYMYModels.h' # Now actually commented out

  s.static_framework = false # Temporarily changed for diagnostics

  # Removed, will use OTHER_CFLAGS
  # s.module_map = 'Headers/niimbot.modulemap'

  # It's better to ensure the `Headers` directory is copied to a place where the module map can find it.
  # `s.preserve_paths` can ensure the Headers directory (containing .h and .modulemap) is available.
  s.preserve_paths = 'Headers/**/*', 'libs/*'
  
  s.vendored_libraries = 'libs/libJCAPI.a', 'libs/libJCLPAPI.a', 'libs/libSkiaRenderLibrary.a'
  s.frameworks = 'AVFoundation', 'CoreMedia', 'CoreBluetooth', 'CoreAudio'
  s.libraries = 'bz2.1.0', 'iconv.2', 'c++'

  # Resources (e.g., for fonts) - Include all .ttc, .ttf, and .json files from Assets
  s.resources = ['Assets/*.ttc', 'Assets/*.ttf', 'Assets/*.json']

  s.dependency 'Flutter'
  s.platform = :ios, '17.2'

  # Swift version
  s.swift_version = '5.0'

  # Configuration based on typical Flutter plugin and SDK needs
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES', # Enable Objective-C modules
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO', # Important for bridging header compatibility
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 i386', # UPDATED: Exclude x86_64 and i386 for simulator
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.2', # Explicitly set deployment target
    'OTHER_LDFLAGS' => '$(inherited) -ObjC', # Back to just -ObjC, removed -ld_classic as user did
    # HEADER_SEARCH_PATHS should point to the directory containing the headers referenced by the module map.
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Headers"', 
    'OTHER_CFLAGS' => '$(inherited) -fmodule-map-file="$(PODS_TARGET_SRCROOT)/Headers/NiimbotObjCSDK.modulemap"',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -Xcc -fmodule-map-file="$(PODS_TARGET_SRCROOT)/Headers/NiimbotObjCSDK.modulemap"'
  }
end
