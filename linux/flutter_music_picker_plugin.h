#ifndef FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_linux.h>

#include <memory>
#include <set>
#include <string>
#include <vector>

namespace flutter_music_picker {

/// The Linux implementation of the flutter_music_picker plugin.
///
/// Scans the user's XDG Music directory (~/Music) and system sound
/// directories (/usr/share/sounds) for audio files. Plays ringtones
/// by forking paplay/aplay/ffplay.
class FlutterMusicPickerPlugin : public flutter::Plugin {
 public:
  /// Registers this plugin with the Flutter engine.
  static void RegisterWithRegistrar(flutter::PluginRegistrarLinux *registrar);

  FlutterMusicPickerPlugin();
  virtual ~FlutterMusicPickerPlugin();

  FlutterMusicPickerPlugin(const FlutterMusicPickerPlugin&) = delete;
  FlutterMusicPickerPlugin& operator=(const FlutterMusicPickerPlugin&) = delete;

 private:
  /// Dispatches method calls from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Recursively scans a directory for audio files.
  std::vector<flutter::EncodableValue> ScanDirectory(
      const std::string& directory_path, bool is_ringtone);

  /// Builds a metadata map for one audio file.
  flutter::EncodableValue BuildAudioFileEntry(
      const std::string& file_path,
      uint64_t file_size,
      bool is_ringtone);

  /// Plays a ringtone by forking a system audio player.
  void PlayRingtoneFile(const std::string& file_path);
  void StopRingtone();

  /// Recognized audio file extensions.
  std::set<std::string> audio_extensions_;

  /// PID of the forked audio player process, -1 if none.
  int player_pid_ = -1;

  /// The method channel  --  kept alive to prevent handler unregistration.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace flutter_music_picker

#endif  // FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_
