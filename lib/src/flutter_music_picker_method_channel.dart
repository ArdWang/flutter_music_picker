import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_music_picker_platform_interface.dart';
import 'music_item.dart';

/// An implementation of [FlutterMusicPickerPlatform] that uses
/// [MethodChannel] to communicate with native platform code.
///
/// This is the default implementation on Android, iOS, macOS,
/// Windows, and Linux. Each platform registers a native handler
/// for the channel `com.rnd.flutter_music_picker/music_picker`.
class MethodChannelFlutterMusicPicker extends FlutterMusicPickerPlatform {
  /// The method channel used for Dart-to-native communication.
  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel(
    'com.rnd.flutter_music_picker/music_picker',
  );

  @override
  Future<List<MusicItem>> getMusicFiles() async {
    try {
      final List<dynamic> result = await methodChannel.invokeMethod(
        'getMusicFiles',
      );
      return _parseResultList(result);
    } on MissingPluginException {
      return [];
    } on PlatformException catch (e) {
      throw MusicPickerException(
        'Failed to retrieve music files: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<List<MusicItem>> getRingtones() async {
    try {
      final List<dynamic> result = await methodChannel.invokeMethod(
        'getRingtones',
      );
      return _parseResultList(result);
    } on MissingPluginException {
      return [];
    } on PlatformException catch (e) {
      throw MusicPickerException(
        'Failed to retrieve ringtones: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<void> playRingtone(String uri) async {
    try {
      await methodChannel.invokeMethod('playRingtone', {'uri': uri});
    } on MissingPluginException {
      // Platform doesn't support native ringtone playback — no-op.
    } on PlatformException catch (e) {
      throw MusicPickerException(
        'Failed to play ringtone: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<void> stopRingtone() async {
    try {
      await methodChannel.invokeMethod('stopRingtone');
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException catch (e) {
      throw MusicPickerException(
        'Failed to stop ringtone: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Parses a list of maps from the platform channel into [MusicItem] objects.
  List<MusicItem> _parseResultList(List<dynamic> rawList) {
    return rawList
        .cast<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(MusicItem.fromMap)
        .toList();
  }
}

/// Exception thrown when a music picker operation fails on the
/// native platform side.
class MusicPickerException implements Exception {
  /// Creates a [MusicPickerException] with a human-readable [message]
  /// and an optional platform error [code].
  const MusicPickerException(this.message, {this.code});

  /// Human-readable description of what went wrong.
  final String message;

  /// Platform-specific error code, if available.
  final String? code;

  @override
  String toString() =>
      'MusicPickerException: $message${code != null ? ' (code: $code)' : ''}';
}
