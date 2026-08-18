import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/services/on_device_speech_recognition_service.dart';

/// Uses the best available explicitly offline Android recognition engine.
///
/// The native layer prefers Android's dedicated API 31+ engine and otherwise
/// uses the Vosk model bundled in the APK. It never calls Android's ordinary
/// recognizer because that API may use a remote service.
class AndroidOnDeviceSpeechRecognitionService
    implements OnDeviceSpeechRecognitionService {
  static const _channel = MethodChannel(
    'ai_blind_assistant/on_device_speech_recognizer',
  );
  final StreamController<HandsFreeSpeechEvent> _handsFreeEvents =
      StreamController<HandsFreeSpeechEvent>.broadcast();

  AndroidOnDeviceSpeechRecognitionService() {
    _channel.setMethodCallHandler(_onNativeCallback);
  }

  @override
  Stream<HandsFreeSpeechEvent> get handsFreeEvents => _handsFreeEvents.stream;

  Future<dynamic> _onNativeCallback(MethodCall call) async {
    final eventType = switch (call.method) {
      'onHandsFreeWake' => HandsFreeSpeechEventType.wake,
      'onHandsFreeCommand' => HandsFreeSpeechEventType.command,
      'onHandsFreeTimeout' => HandsFreeSpeechEventType.timeout,
      'onHandsFreeError' => HandsFreeSpeechEventType.error,
      _ => null,
    };
    if (eventType == null || _handsFreeEvents.isClosed) return null;
    final arguments = call.arguments;
    final transcript = arguments is Map
        ? arguments['transcript']?.toString().trim()
        : null;
    _handsFreeEvents.add(
      HandsFreeSpeechEvent(type: eventType, transcript: transcript),
    );
    return null;
  }

  @override
  Future<OnDeviceSpeechAvailability> checkAvailability() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'checkAvailability',
      );
      return OnDeviceSpeechAvailability(
        available: raw?['available'] == true,
        platformVersion: (raw?['platformVersion'] as num?)?.toInt() ?? 0,
        reason: raw?['reason'] as String?,
        provider: raw?['provider'] as String?,
        dedicatedAndroidAvailable: raw?['dedicatedAndroidAvailable'] == true,
        bundledOfflineAvailable: raw?['bundledOfflineAvailable'] == true,
      );
    } on MissingPluginException {
      return const OnDeviceSpeechAvailability(
        available: false,
        platformVersion: 0,
        reason: 'Offline speech recognition is unavailable in this build.',
      );
    } on PlatformException catch (error) {
      return OnDeviceSpeechAvailability(
        available: false,
        platformVersion: 0,
        reason: error.message ?? 'Offline speech recognition is unavailable.',
      );
    }
  }

  @override
  Future<void> startListening({required String locale}) async {
    try {
      final started = await _channel.invokeMethod<bool>('startListening', {
        'locale': locale,
      });
      if (started != true) {
        throw const OnDeviceSpeechRecognitionException(
          'start_failed',
          'Offline speech recognition could not start.',
        );
      }
    } on OnDeviceSpeechRecognitionException {
      rethrow;
    } on MissingPluginException {
      throw const OnDeviceSpeechRecognitionException(
        'unavailable',
        'Offline speech recognition is unavailable in this build.',
      );
    } on PlatformException catch (error) {
      throw OnDeviceSpeechRecognitionException(
        error.code,
        error.message ?? 'Offline speech recognition could not start.',
      );
    }
  }

  @override
  Future<OnDeviceSpeechResult> stopListening() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'stopListening',
      );
      final transcript = (raw?['transcript'] as String? ?? '').trim();
      return OnDeviceSpeechResult(
        transcript: transcript,
        confidence: (raw?['confidence'] as num?)?.toDouble(),
      );
    } on MissingPluginException {
      throw const OnDeviceSpeechRecognitionException(
        'unavailable',
        'Offline speech recognition is unavailable in this build.',
      );
    } on PlatformException catch (error) {
      throw OnDeviceSpeechRecognitionException(
        error.code,
        error.message ?? 'Your speech could not be recognized on this device.',
      );
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _channel.invokeMethod<void>('cancelListening');
    } on MissingPluginException {
      // Already unavailable; there is no native resource to release.
    } catch (_) {
      // Cancellation remains best-effort during lifecycle cleanup.
    }
  }

  @override
  Future<void> startHandsFree({required String locale}) async {
    try {
      final started = await _channel.invokeMethod<bool>('startHandsFree', {
        'locale': locale,
      });
      if (started != true) {
        throw const OnDeviceSpeechRecognitionException(
          'start_failed',
          'Hands-free offline recognition could not start.',
        );
      }
    } on OnDeviceSpeechRecognitionException {
      rethrow;
    } on MissingPluginException {
      throw const OnDeviceSpeechRecognitionException(
        'unavailable',
        'Hands-free offline recognition is unavailable in this build.',
      );
    } on PlatformException catch (error) {
      throw OnDeviceSpeechRecognitionException(
        error.code,
        error.message ?? 'Hands-free offline recognition could not start.',
      );
    }
  }

  @override
  Future<void> pauseHandsFree() => _bestEffortMethod('pauseHandsFree');

  @override
  Future<void> resumeHandsFree({bool acceptNextCommand = false}) =>
      _bestEffortMethod('resumeHandsFree', {
        'acceptNextCommand': acceptNextCommand,
      });

  @override
  Future<void> stopHandsFree() => _bestEffortMethod('stopHandsFree');

  @override
  Future<void> setRecognitionProfile(String profile) =>
      _bestEffortMethod('setRecognitionProfile', {'profile': profile});

  Future<void> _bestEffortMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The service is already unavailable.
    } on PlatformException {
      // Lifecycle cleanup and pause/resume remain best effort.
    }
  }

  @override
  Future<void> dispose() async {
    await stopHandsFree();
    await cancelListening();
    _channel.setMethodCallHandler(null);
    await _handsFreeEvents.close();
  }
}
