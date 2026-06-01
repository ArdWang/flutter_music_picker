#ifndef FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <set>
#include <string>
#include <vector>

namespace flutter_music_picker {

/// The Windows implementation of the flutter_music_picker plugin.
///
/// Scans the user's Music folder and Public Music for music files,
/// and C:\Windows\Media for system ringtones/notification sounds.
/// Uses Win32 PlaySound API for ringtone preview.
class FlutterMusicPickerPlugin : public flutter::Plugin {
 public:
  /// Registers this plugin with the Flutter engine.
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar);

  FlutterMusicPickerPlugin();
  virtual ~FlutterMusicPickerPlugin();

  FlutterMusicPickerPlugin(const FlutterMusicPickerPlugin&) = delete;
  FlutterMusicPickerPlugin& operator=(const FlutterMusicPickerPlugin&) = delete;

 private:
  /// Dispatches method calls from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Scans a directory recursively for audio files.
  std::vector<flutter::EncodableValue> ScanDirectory(
      const std::wstring& directory_path, bool is_ringtone);

  /// Builds a metadata map for one audio file.
  flutter::EncodableValue BuildAudioFileEntry(
      const std::wstring& file_path,
      uint64_t file_size,
      bool is_ringtone);

  /// Plays a ringtone via Win32 PlaySound.
  void PlayRingtoneFile(const std::wstring& file_path);
  void StopRingtone();

  /// Converts a wide string to UTF-8.
  std::string WideToUtf8(const std::wstring& wstr);

  /// Recognized audio file extensions.
  std::set<std::wstring> audio_extensions_;

  /// The method channel  --  kept alive to prevent handler unregistration.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace flutter_music_picker

#endif  // FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_
