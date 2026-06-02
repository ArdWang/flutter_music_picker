#
# The iOS podspec for the flutter_music_picker plugin.
#
# This file tells CocoaPods how to build the iOS portion of the plugin
# and which frameworks it depends on. The MediaPlayer framework is
# required for querying the device's music library.
#
# To learn more about podspec attributes, see:
# https://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_music_picker'
  s.version          = '0.0.7'
  s.summary          = 'A Flutter plugin for picking music files and ringtones.'
  s.description      = <<-DESC
A Flutter plugin that discovers and lists music files and ringtones
from the device across Android, iOS, macOS, Windows, Linux, and Web.
                       DESC
  s.homepage         = 'https://github.com/ArdWang/flutter_music_picker'
  s.license          = { :type => 'MIT' }
  s.author           = { 'ArdWang' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  # The MediaPlayer framework is needed on iOS to query the music library
  s.framework = 'MediaPlayer'

  # Deployment target version
  s.platform = :ios, '12.0'

  # Use Swift for the plugin implementation
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_VERSION' => '5.0'
  }

end
