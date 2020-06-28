#
#  Be sure to run `pod spec lint LibWally.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name         = "LibWally"
  spec.version      = "0.0.1"
  spec.summary      = "Swift wrapper for LibWally."

  spec.description  = <<-DESC
  Swift wrapper for LibWally, a collection of useful primitives for cryptocurrency wallets.
                   DESC

  spec.homepage     = "https://github.com/blockchain/libwally-swift"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

  # spec.platform     = :ios
  spec.platform     = :ios, "10"

  spec.swift_version = '5'

  #  When using multiple platforms
  # spec.ios.deployment_target = "5.0"
  # spec.osx.deployment_target = "10.7"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"

  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.license      = { :type => "MIT", :file => "LICENSE.md" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the authors of the library, with email addresses.

  spec.authors             = { "Sjors Provoost" => "sjors@sprovoost.nl" }

  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  spec.source       = { :git => "https://github.com/blockchain/libwally-swift.git", :tag => "#{spec.version}", :submodules => true  }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any swift, h, m, mm, c & cpp files.
  #  For header files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  spec.source_files  = "LibWally"

  # spec.public_header_files = "LibWally/LibWally.h", "CLibWally/libwally-core/include/*.h" #, "CLibWally/libwally-core/src/secp256k1/include/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.

  # spec.resource  = "icon.png"
  # spec.resources = "Resources/*.png"

  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # spec.framework  = "SomeFramework"
  # spec.frameworks = "SomeFramework", "AnotherFramework"

  # spec.library   = "iconv"
  # spec.libraries = "iconv", "xml2"

  spec.vendored_libraries = "CLibWally/libwally-core/src/.libs/libwallycore.a"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  spec.pod_target_xcconfig = {
                               'SWIFT_WHOLE_MODULE_OPTIMIZATION' => 'YES',
                               'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/CLibWally',
                               'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/CLibWally/libwally-core/include',
                               'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/CLibWally/libwally-core/src/.libs' }
  spec.preserve_paths = 'LibWally/LibWally.modulemap', 'CLibWally'

  spec.module_map = 'LibWally/LibWally.modulemap'

  spec.prepare_command = './build-libwally.sh -sdc'

end
