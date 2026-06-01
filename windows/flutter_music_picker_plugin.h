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
///
/// All queries are pure filesystem enumeration with no per-file
/// metadata reads (durationMs = 0, sizeBytes from directory entry)
/// to avoid blocking the main thread.
class FlutterMusicPickerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar);

  FlutterMusicPickerPlugin();
  virtual ~FlutterMusicPickerPlugin();

  FlutterMusicPickerPlugin(const FlutterMusicPickerPlugin&) = delete;
  FlutterMusicPickerPlugin& operator=(const FlutterMusicPickerPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::vector<flutter::EncodableValue> ScanDirectory(
      const std::wstring& directory_path, bool is_ringtone);

  flutter::EncodableValue BuildAudioFileEntry(
      const std::wstring& file_path,
      uint64_t file_size,
      bool is_ringtone);

  void PlayRingtoneFile(const std::wstring& file_path);
  void StopRingtone();

  std::string WideToUtf8(const std::wstring& wstr);

  std::set<std::wstring> audio_extensions_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace flutter_music_picker

#endif  // FLUTTER_PLUGIN_FLUTTER_MUSIC_PICKER_PLUGIN_H_
