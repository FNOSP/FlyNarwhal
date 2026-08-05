#
# Vendored podspec for the local override of media_kit_libs_macos_video.
# The Makefile downloads the full FFmpeg/mpv XCFramework (containing the
# hdmv_pgs_subtitle decoder) into Frameworks/ and the pod ships it as a
# vendored framework.
#
Pod::Spec.new do |s|
  system("make")

  s.name             = 'media_kit_libs_macos_video'
  s.version          = '1.1.4'
  s.summary          = 'macOS dependency package for package:media_kit (full FFmpeg/mpv)'
  s.description      = <<-DESC
  macOS dependency package for package:media_kit using the full FFmpeg/mpv
  XCFramework (PGS/HDMV SUP bitmap subtitle support).
                       DESC
  s.homepage         = 'https://github.com/media-kit/media-kit.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hitesh Kumar Saini' => 'saini123hitesh@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.vendored_frameworks = 'Frameworks/*.xcframework'

  s.platform = :osx, '10.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
