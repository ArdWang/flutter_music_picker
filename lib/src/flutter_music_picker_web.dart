import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'flutter_music_picker_platform_interface.dart';
import 'logger.dart';

/// The web implementation of [FlutterMusicPickerPlatform].
///
/// Web browsers restrict direct filesystem access for security reasons.
/// This implementation provides a method channel handler that returns
/// sample data so the example app has content to display.
///
/// For a production web app, consider:
/// 1. Fetching audio metadata from a server-side API.
/// 2. Using the File System Access API to let users pick files.
/// 3. Using an `<input type="file">` element for user-driven selection.
class FlutterMusicPickerWeb extends FlutterMusicPickerPlatform {
  /// The method channel used for web plugin communication.
  static const MethodChannel _channel = MethodChannel(
    'com.rnd.flutter_music_picker/music_picker',
  );

  static const _log = AppLogger('Web');

  /// Registers this web implementation with the plugin system.
  ///
  /// Called once during application startup by the Flutter web engine.
  /// Overrides the default platform instance with this web implementation.
  static void registerWith(Registrar registrar) {
    final instance = FlutterMusicPickerWeb();
    FlutterMusicPickerPlatform.instance = instance;
    _channel.setMethodCallHandler(instance._handleMethodCall);
    _log.info('registered as web platform implementation');
  }

  /// Handles incoming method calls from the Dart side.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _log.info('${call.method}() → handling');
    switch (call.method) {
      case 'getMusicFiles':
        final data = await _getSampleMusicFiles();
        _log.info('getMusicFiles() ← ${data.length} sample items');
        return data;
      case 'getRingtones':
        final data = await _getSampleRingtones();
        _log.info('getRingtones() ← ${data.length} sample items');
        return data;
      case 'playRingtone':
        _log.debug('playRingtone() ← no-op on web');
        return true;
      case 'stopRingtone':
        _log.debug('stopRingtone() ← no-op on web');
        return true;
      default:
        _log.warn('${call.method}() ← not implemented on web');
        throw MissingPluginException(
          'Method ${call.method} is not implemented on web.',
        );
    }
  }

  /// Returns sample music file data for display in the example app.
  Future<List<Map<String, dynamic>>> _getSampleMusicFiles() async {
    return [
      {
        'id': 'sample_1',
        'title': 'Sample Song 1',
        'artist': 'Demo Artist',
        'album': 'Demo Album',
        'durationMs': 210000,
        'uri': '',
        'sizeBytes': 4200000,
        'isRingtone': false,
      },
      {
        'id': 'sample_2',
        'title': 'Sample Song 2',
        'artist': 'Demo Artist',
        'album': 'Demo Album',
        'durationMs': 195000,
        'uri': '',
        'sizeBytes': 3800000,
        'isRingtone': false,
      },
    ];
  }

  /// Returns sample ringtone data for display in the example app.
  Future<List<Map<String, dynamic>>> _getSampleRingtones() async {
    return [
      {
        'id': 'sample_ring_1',
        'title': 'Classic Bell (Ringtone)',
        'artist': 'System',
        'album': 'Ringtones',
        'durationMs': 30000,
        'uri': '',
        'sizeBytes': 500000,
        'isRingtone': true,
      },
      {
        'id': 'sample_ring_2',
        'title': 'Notification Chime (Notification)',
        'artist': 'System',
        'album': 'Notifications',
        'durationMs': 5000,
        'uri': '',
        'sizeBytes': 80000,
        'isRingtone': true,
      },
      {
        'id': 'sample_ring_3',
        'title': 'Alarm Tone (Alarm)',
        'artist': 'System',
        'album': 'Alarms',
        'durationMs': 15000,
        'uri': '',
        'sizeBytes': 300000,
        'isRingtone': true,
      },
    ];
  }
}
