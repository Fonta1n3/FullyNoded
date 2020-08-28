#
#  Be sure to run `pod spec lint LibWally.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#

Pod::Spec.new do |spec|

  spec.name         = "LibWally"
  spec.version      = "0.0.1"
  spec.summary      = "Swift wrapper for LibWally."
  spec.description  = "Swift wrapper for LibWally, a collection of useful primitives for cryptocurrency wallets."
  spec.homepage     = "https://github.com/blockchain/libwally-swift"

  spec.license      = { :type => "MIT", :file => "LICENSE.md" }
  spec.authors      = { "Sjors Provoost" => "sjors@sprovoost.nl" }

  spec.platform     = :ios, "10"
  spec.swift_version = '5.0'

  spec.source       = { :git => "https://github.com/blockchain/libwally-swift.git", :tag => "v#{spec.version}", :submodules => true  }

  spec.source_files = "LibWally"

  spec.vendored_libraries = "CLibWally/libwally-core/src/.libs/libwallycore.a"

  spec.pod_target_xcconfig = {
                               'SWIFT_WHOLE_MODULE_OPTIMIZATION' => 'YES',
                               'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/CLibWally',
                               'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/CLibWally/libwally-core/src/.libs'
                             }
  spec.preserve_paths = 'LibWally/LibWally.modulemap', 'CLibWally'

  spec.module_map = 'LibWally/LibWally.modulemap'

  spec.prepare_command = './build-libwally.sh -sdc'

end
