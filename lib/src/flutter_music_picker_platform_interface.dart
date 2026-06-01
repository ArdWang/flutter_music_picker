import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'music_item.dart';

/// The abstract interface that every platform-specific implementation
/// of flutter_music_picker must implement.
///
/// Subclasses on each platform provide concrete methods that query the
/// native OS for audio files (music and ringtones) and optionally play
/// ringtones using native system APIs.
abstract class FlutterMusicPickerPlatform extends PlatformInterface {
  /// Constructs a [FlutterMusicPickerPlatform].
  FlutterMusicPickerPlatform() : super(token: _token);

  /// Token used to verify that the instance is not set to a non-mock
  /// implementation outside of tests.
  static final Object _token = Object();

  /// The default instance, lazily replaced by the real implementation.
  static FlutterMusicPickerPlatform _instance =
      _DefaultFlutterMusicPickerPlatform();

  /// The current [FlutterMusicPickerPlatform] instance.
  static FlutterMusicPickerPlatform get instance => _instance;

  /// Sets the current [FlutterMusicPickerPlatform] instance.
  static set instance(FlutterMusicPickerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Retrieves all music files available on the device.
  Future<List<MusicItem>> getMusicFiles() {
    throw UnimplementedError('getMusicFiles() not implemented.');
  }

  /// Retrieves all ringtones available on the device.
  Future<List<MusicItem>> getRingtones() {
    throw UnimplementedError('getRingtones() not implemented.');
  }

  /// Plays a ringtone using the platform's native audio system.
  ///
  /// On Android this uses [android.media.RingtoneManager.getRingtone].
  /// On iOS/macOS this uses AVAudioPlayer to preview the sound.
  /// On other platforms this is a no-op; use an audio player instead.
  Future<void> playRingtone(String uri) async {}

  /// Stops the currently playing ringtone.
  ///
  /// Call this when the user navigates away or selects a different
  /// ringtone to preview.
  Future<void> stopRingtone() async {}
}

/// A default no-op implementation used as a fallback before the
/// platform-specific implementation is registered.
class _DefaultFlutterMusicPickerPlatform extends FlutterMusicPickerPlatform {
  @override
  Future<List<MusicItem>> getMusicFiles() async => [];

  @override
  Future<List<MusicItem>> getRingtones() async => [];
}
