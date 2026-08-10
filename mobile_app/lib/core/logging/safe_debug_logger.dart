import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class SafeDebugLogger implements AppLogger {
  const SafeDebugLogger();

  @override
  void debug(String message) {
    _log('DEBUG', message);
  }

  @override
  void info(String message) {
    _log('INFO', message);
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log('WARN', message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[AI Blind Assistant][$level] ${_safe(message)}');
    if (error != null) {
      debugPrint('[AI Blind Assistant][$level] Error: ${_safe('$error')}');
    }
    if (stackTrace != null) {
      debugPrint('[AI Blind Assistant][$level] Stack trace available.');
    }
  }

  String _safe(String value) {
    return value.length <= 500 ? value : '${value.substring(0, 500)}...';
  }
}
