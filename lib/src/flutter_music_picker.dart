import 'dart:async';

import 'flutter_music_picker_method_channel.dart';
import 'flutter_music_picker_platform_interface.dart';
import 'music_item.dart';

/// The main entry-point class for the flutter_music_picker plugin.
///
/// Provides static methods to query the device for music files and
/// ringtones, as well as previewing ringtones using native system APIs.
///
/// Example usage:
/// ```dart
/// // Get all music files on the device
/// final musicFiles = await FlutterMusicPicker.getMusicFiles();
///
/// // Get all ringtones on the device
/// final ringtones = await FlutterMusicPicker.getRingtones();
///
/// // Preview a ringtone using native playback
/// await FlutterMusicPicker.playRingtone(ringtones[0].uri);
///
/// // Stop the preview
/// await FlutterMusicPicker.stopRingtone();
/// ```
class FlutterMusicPicker {
  FlutterMusicPicker._();

  /// Ensures the platform implementation is initialized before any
  /// method call. This replaces the unreliable top-level `_initialized`
  /// variable which Dart may optimize away.
  static bool _platformInitialized = false;

  static void _ensureInitialized() {
    if (!_platformInitialized) {
      FlutterMusicPickerPlatform.instance = MethodChannelFlutterMusicPicker();
      _platformInitialized = true;
    }
  }

  /// Retrieves all music files available on the device.
  ///
  /// - **Android**: Queries MediaStore for audio files where `IS_MUSIC`
  ///   is true. Requires `READ_MEDIA_AUDIO` permission (API 33+).
  /// - **iOS**: Uses `MPMediaQuery` to list songs from the music library.
  ///   Requires `NSAppleMusicUsageDescription` in Info.plist.
  /// - **macOS**: Scans `~/Music` and common audio directories.
  /// - **Windows**: Scans the user's Music folder and Public Music.
  /// - **Linux**: Scans `~/Music` and XDG audio directories.
  /// - **Web**: Returns sample data (browsers restrict filesystem access).
  static Future<List<MusicItem>> getMusicFiles() {
    _ensureInitialized();
    return FlutterMusicPickerPlatform.instance.getMusicFiles();
  }

  /// Retrieves all ringtones and notification sounds on the device.
  ///
  /// - **Android**: Uses `RingtoneManager` to list system ringtones,
  ///   notification sounds, and alarm tones. Provides proper content URIs
  ///   usable with [playRingtone].
  /// - **iOS**: Returns known system ringtone identifiers.
  /// - **macOS**: Scans `/System/Library/Sounds` and related directories.
  /// - **Windows**: Scans `C:\Windows\Media` for system sounds.
  /// - **Linux**: Scans `/usr/share/sounds` for system sound files.
  /// - **Web**: Returns sample data.
  static Future<List<MusicItem>> getRingtones() {
    _ensureInitialized();
    return FlutterMusicPickerPlatform.instance.getRingtones();
  }

  /// Retrieves both music files and ringtones combined into a single list.
  static Future<List<MusicItem>> getAllAudioFiles() async {
    final results = await Future.wait([
      getMusicFiles(),
      getRingtones(),
    ]);
    return [...results[0], ...results[1]];
  }

  /// Plays a ringtone using the platform's native audio system.
  ///
  /// On Android this uses `RingtoneManager.getRingtone()` which plays
  /// through the system's ringtone/notification audio channel.
  ///
  /// On iOS/macOS this uses AVAudioPlayer for local preview.
  ///
  /// On desktop and web this is a no-op — use an audio player package
  /// like `just_audio` for playback on those platforms.
  ///
  /// Call [stopRingtone] to end playback.
  static Future<void> playRingtone(String uri) {
    _ensureInitialized();
    return FlutterMusicPickerPlatform.instance.playRingtone(uri);
  }

  /// Stops the currently playing ringtone preview.
  ///
  /// Safe to call even if no ringtone is currently playing.
  static Future<void> stopRingtone() {
    _ensureInitialized();
    return FlutterMusicPickerPlatform.instance.stopRingtone();
  }

  /// Whether this platform is capable of querying music files.
  static bool get isSupported => true;
}
