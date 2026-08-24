import 'dart:async';
import 'package:flutter/services.dart';

/// Flutter-side lightweight bridge for optional Porcupine wake-word.
///
/// This bridge exposes start/stop and a stream of wake events. When
/// Porcupine native integration is added, the native side should call
/// the platform method `onHandsFreeWake` on the same channel to reuse
/// the existing hands-free handling pipeline.
class PorcupineBridge {
  static const MethodChannel _channel = MethodChannel(
    'ai_blind_assistant/porcupine',
  );
  static final _wakeController = StreamController<void>.broadcast();

  static Stream<void> get wakes => _wakeController.stream;

  static void _nativeCallback(MethodCall call) {
    if (call.method == 'onHandsFreeWake') {
      _wakeController.add(null);
    }
  }

  static Future<bool> start() async {
    _channel.setMethodCallHandler((call) async {
      _nativeCallback(call);
      return null;
    });
    try {
      final started = await _channel.invokeMethod<bool>('startPorcupine');
      return started == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final stopped = await _channel.invokeMethod<bool>('stopPorcupine');
      return stopped == true;
    } catch (_) {
      return false;
    }
  }

  static void dispose() {
    _wakeController.close();
  }
}
