import 'package:flutter/foundation.dart';

/// Colored console logger for debugging the flutter_music_picker plugin.
///
/// Uses emoji + ANSI escape codes for terminal color output. Each instance
/// is bound to a [tag] (usually the class name) so log lines are traceable.
///
/// ```
/// final _log = AppLogger('MethodChannel');
/// _log.info('Retrieved 42 music files');
/// _log.error('PlatformException: permission denied');
/// ```
class AppLogger {
  const AppLogger(this.tag);

  final String tag;

  void debug(String msg) => _log('DEBUG', '\u{1F50D}', msg, _Ansi.gray);
  void info(String msg) => _log('INFO ', '\u{2139}\u{FE0F} ', msg, _Ansi.green);
  void warn(String msg) => _log('WARN ', '\u{26A0}\u{FE0F} ', msg, _Ansi.yellow);
  void error(String msg, [Object? error, String? stackTrace]) {
    _log('ERROR', '\u{274C} ', msg, _Ansi.red);
    if (error != null) {
      _print('       \u{2514}\u{2500} $error', _Ansi.red);
    }
    if (stackTrace != null) {
      _print('       \u{2514}\u{2500} $stackTrace', _Ansi.red);
    }
  }

  void _log(String level, String emoji, String msg, String color) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    _print('$emoji[$ts] $level [$tag] $msg', color);
  }

  void _print(String line, String color) {
    debugPrint('$color$line${_Ansi.reset}');
  }
}

/// Terminal color helpers (private to this file).
class _Ansi {
  const _Ansi._();

  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const gray = '\x1B[90m';
}
