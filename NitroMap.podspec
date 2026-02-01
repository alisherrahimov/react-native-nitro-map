require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "NitroMap"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => '16.0' }
  s.source       = { :git => "https://github.com/alisherrahimov/react-native-nitro-map.git", :tag => "#{s.version}" }

  s.source_files = [
    "ios/**/*.{swift,h,m,mm}",
    "cpp/**/*.{h,hpp,cpp}",
  ]

  # C++ settings for ClusterEngine
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/cpp"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited)'
  }

  # Expose Objective-C++ wrapper header for Swift
  s.public_header_files = [
    "ios/Clustering/ClusterEngineWrapper.h"
  ]

  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'
  s.dependency 'GoogleMaps', '~> 10.7.0'
  s.dependency 'Google-Maps-iOS-Utils', '~> 6.1.3'
  s.dependency 'YandexMapsMobile', '4.29.0-lite'
  load 'nitrogen/generated/ios/NitroMap+autolinking.rb'
  add_nitrogen_files(s)

  install_modules_dependencies(s)
end
