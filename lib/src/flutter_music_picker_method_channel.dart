import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_music_picker_platform_interface.dart';
import 'logger.dart';
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

  static const _log = AppLogger('MethodChannel');

  @override
  Future<List<MusicItem>> getMusicFiles() async {
    _log.info('getMusicFiles() → calling native method');
    try {
      final List<dynamic> result = await methodChannel.invokeMethod(
        'getMusicFiles',
      );
      final items = _parseResultList(result);
      _log.info('getMusicFiles() ← ${items.length} items');
      return items;
    } on MissingPluginException {
      _log.warn('getMusicFiles() ← MissingPluginException, returning []');
      return [];
    } on PlatformException catch (e) {
      _log.error(
        'getMusicFiles() ← PlatformException: ${e.message} (code: ${e.code})',
        e,
        e.stacktrace,
      );
      throw MusicPickerException(
        'Failed to retrieve music files: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<List<MusicItem>> getRingtones() async {
    _log.info('getRingtones() → calling native method');
    try {
      final List<dynamic> result = await methodChannel.invokeMethod(
        'getRingtones',
      );
      final items = _parseResultList(result);
      _log.info('getRingtones() ← ${items.length} items');
      return items;
    } on MissingPluginException {
      _log.warn('getRingtones() ← MissingPluginException, returning []');
      return [];
    } on PlatformException catch (e) {
      _log.error(
        'getRingtones() ← PlatformException: ${e.message} (code: ${e.code})',
        e,
        e.stacktrace,
      );
      throw MusicPickerException(
        'Failed to retrieve ringtones: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<void> playRingtone(String uri) async {
    _log.info('playRingtone(uri: $uri) → calling native method');
    try {
      await methodChannel.invokeMethod('playRingtone', {'uri': uri});
      _log.debug('playRingtone() ← ok');
    } on MissingPluginException {
      _log.warn('playRingtone() ← MissingPluginException (no-op)');
    } on PlatformException catch (e) {
      _log.error(
        'playRingtone() ← PlatformException: ${e.message} (code: ${e.code})',
        e,
        e.stacktrace,
      );
      throw MusicPickerException(
        'Failed to play ringtone: ${e.message}',
        code: e.code,
      );
    }
  }

  @override
  Future<void> stopRingtone() async {
    _log.debug('stopRingtone() → calling native method');
    try {
      await methodChannel.invokeMethod('stopRingtone');
      _log.debug('stopRingtone() ← ok');
    } on MissingPluginException {
      _log.warn('stopRingtone() ← MissingPluginException (no-op)');
    } on PlatformException catch (e) {
      _log.error(
        'stopRingtone() ← PlatformException: ${e.message} (code: ${e.code})',
        e,
        e.stacktrace,
      );
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
