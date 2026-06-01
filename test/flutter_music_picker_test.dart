import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music_picker/flutter_music_picker.dart';

/// Unit tests for the flutter_music_picker plugin.
///
/// These tests verify the [MusicItem] data model and the public API
/// of [FlutterMusicPicker]. Platform-specific functionality (actual
/// music file retrieval) should be tested via integration tests on
/// real devices.
void main() {
  group('MusicItem', () {
    test('should construct from map correctly', () {
      final map = {
        'id': 'test_1',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'album': 'Test Album',
        'durationMs': 240000,
        'uri': '/path/to/song.mp3',
        'sizeBytes': 5000000,
        'isRingtone': false,
      };

      final item = MusicItem.fromMap(map);

      expect(item.id, 'test_1');
      expect(item.title, 'Test Song');
      expect(item.artist, 'Test Artist');
      expect(item.album, 'Test Album');
      expect(item.durationMs, 240000);
      expect(item.uri, '/path/to/song.mp3');
      expect(item.sizeBytes, 5000000);
      expect(item.isRingtone, false);
    });

    test('should convert to map correctly', () {
      const item = MusicItem(
        id: 'test_1',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        durationMs: 240000,
        uri: '/path/to/song.mp3',
        sizeBytes: 5000000,
        isRingtone: false,
      );

      final map = item.toMap();

      expect(map['id'], 'test_1');
      expect(map['title'], 'Test Song');
      expect(map['artist'], 'Test Artist');
      expect(map['album'], 'Test Album');
      expect(map['durationMs'], 240000);
      expect(map['uri'], '/path/to/song.mp3');
      expect(map['sizeBytes'], 5000000);
      expect(map['isRingtone'], false);
    });

    test('formattedSize should return human-readable size strings', () {
      const smallFile = MusicItem(
        id: '1', title: 'S', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 500, isRingtone: false,
      );
      expect(smallFile.formattedSize, '500 B');

      const kbFile = MusicItem(
        id: '2', title: 'K', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 2048, isRingtone: false,
      );
      expect(kbFile.formattedSize, '2.0 KB');

      const mbFile = MusicItem(
        id: '3', title: 'M', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 5 * 1024 * 1024, isRingtone: false,
      );
      expect(mbFile.formattedSize, '5.0 MB');
    });

    test('formattedDuration should return mm:ss format', () {
      const item = MusicItem(
        id: '1', title: '', artist: '', album: '',
        durationMs: 225000, uri: '', sizeBytes: 0, isRingtone: false,
      );
      expect(item.formattedDuration, '3:45');
    });

    test('equality should be based on id', () {
      const a = MusicItem(
        id: 'same', title: 'A', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 0, isRingtone: false,
      );
      const b = MusicItem(
        id: 'same', title: 'B', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 0, isRingtone: false,
      );
      const c = MusicItem(
        id: 'different', title: 'A', artist: '', album: '',
        durationMs: 0, uri: '', sizeBytes: 0, isRingtone: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('FlutterMusicPicker', () {
    test('isSupported should return true', () {
      expect(FlutterMusicPicker.isSupported, isTrue);
    });
  });

  group('MusicItem.fromMap type coercion', () {
    test('should handle string values for int fields', () {
      final map = {
        'id': 'test',
        'title': 'Song',
        'artist': 'Artist',
        'album': 'Album',
        'durationMs': '240000',  // String, not int
        'uri': '/path',
        'sizeBytes': '5000000',   // String, not int
        'isRingtone': 'true',     // String, not bool
      };

      final item = MusicItem.fromMap(map);

      expect(item.durationMs, 240000);
      expect(item.sizeBytes, 5000000);
      expect(item.isRingtone, true);
    });

    test('should handle int values for bool fields (0/1)', () {
      final map = {
        'id': 'test',
        'title': 'Song',
        'artist': 'Artist',
        'album': 'Album',
        'durationMs': 3000,
        'uri': '/path',
        'sizeBytes': 0,
        'isRingtone': 1,  // int 1 = true
      };

      final item = MusicItem.fromMap(map);
      expect(item.isRingtone, true);

      final map2 = {...map, 'isRingtone': 0};
      final item2 = MusicItem.fromMap(map2);
      expect(item2.isRingtone, false);
    });
  });
}
