/// Represents a single music file or ringtone discovered on the device.
///
/// Each [MusicItem] holds metadata about an audio file including its
/// title, artist, album, duration, file URI, file size, and whether
/// it is a ringtone.
class MusicItem {
  /// Creates a [MusicItem] with the given metadata.
  ///
  /// All parameters are required. Use [fromMap] to construct from a
  /// map received from a native platform channel call.
  const MusicItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.uri,
    required this.sizeBytes,
    required this.isRingtone,
  });

  /// Unique identifier for this music item.
  ///
  /// On Android this is the MediaStore content ID, on iOS it is the
  /// persistent MPMediaEntity ID, and on desktop platforms it is the
  /// absolute file path.
  final String id;

  /// Display title of the audio track (e.g. song name or ringtone label).
  final String title;

  /// Name of the artist who performed this track.
  ///
  /// May be empty or "Unknown" if the metadata is not available.
  final String artist;

  /// Name of the album this track belongs to.
  ///
  /// May be empty or "Unknown" if the metadata is not available.
  final String album;

  /// Playback duration of the track in milliseconds.
  final int durationMs;

  /// Platform-specific URI pointing to the audio file.
  ///
  /// On Android this is a `content://` URI. On other platforms it is
  /// an absolute file path. This URI should be passed to an audio
  /// player component for playback.
  final String uri;

  /// File size in bytes.
  final int sizeBytes;

  /// Whether this item is a system ringtone (notification, alarm, etc.)
  /// as opposed to a regular music track.
  final bool isRingtone;

  /// Constructs a [MusicItem] from a map as returned by the native
  /// platform channel implementations.
  ///
  /// Handles values that may arrive as either their native type (int, bool)
  /// or as strings (from older platform implementations or web). Missing
  /// keys will result in a runtime exception.
  factory MusicItem.fromMap(Map<String, dynamic> map) {
    return MusicItem(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? 'Unknown'}',
      artist: '${map['artist'] ?? 'Unknown'}',
      album: '${map['album'] ?? 'Unknown'}',
      durationMs: _parseInt(map['durationMs']),
      uri: '${map['uri'] ?? ''}',
      sizeBytes: _parseInt(map['sizeBytes']),
      isRingtone: _parseBool(map['isRingtone']),
    );
  }

  /// Safely parses a value from the platform channel map into an int.
  ///
  /// Handles values that are already int, or strings like "0"/"123",
  /// or num/double. Returns 0 for unrecognized types.
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Safely parses a value from the platform channel map into a bool.
  ///
  /// Handles values that are already bool, or strings like "true"/"false",
  /// or int (0 = false, non-zero = true).
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return false;
  }

  /// Converts this [MusicItem] to a map suitable for sending across
  /// the platform channel or for serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'uri': uri,
      'sizeBytes': sizeBytes,
      'isRingtone': isRingtone,
    };
  }

  /// Returns a human-readable file size string (e.g. "4.2 MB").
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns a formatted duration string (e.g. "3:42").
  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'MusicItem(id: $id, title: $title, artist: $artist, uri: $uri)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
