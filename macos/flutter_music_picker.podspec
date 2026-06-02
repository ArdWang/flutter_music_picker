#
# The macOS podspec for the flutter_music_picker plugin.
#
# This file tells CocoaPods how to build the macOS portion of the plugin.
# The AVFoundation framework is required to estimate audio file durations.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_music_picker'
  s.version          = '0.0.7'
  s.summary          = 'A Flutter plugin for picking music files and ringtones on macOS.'
  s.description      = <<-DESC
A Flutter plugin that discovers and lists music files and ringtones
from the filesystem on macOS.
                       DESC
  s.homepage         = 'https://github.com/ArdWang/flutter_music_picker'
  s.license          = { :type => 'MIT' }
  s.author           = { 'ArdWang' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # AVFoundation is used on macOS to estimate audio file durations
  s.framework = 'AVFoundation'

  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_VERSION' => '5.0'
  }

end
