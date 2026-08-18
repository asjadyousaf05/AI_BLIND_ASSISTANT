import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/android_on_device_speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'ai_blind_assistant/on_device_speech_recognizer',
  );
  late AndroidOnDeviceSpeechRecognitionService service;

  setUp(() {
    service = AndroidOnDeviceSpeechRecognitionService();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reports selected offline recognizer availability', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'checkAvailability');
          return <String, dynamic>{
            'available': true,
            'platformVersion': 33,
            'reason': null,
            'provider': 'bundled_vosk',
            'dedicatedAndroidAvailable': false,
            'bundledOfflineAvailable': true,
          };
        });

    final availability = await service.checkAvailability();

    expect(availability.available, isTrue);
    expect(availability.platformVersion, 33);
    expect(availability.reason, isNull);
    expect(availability.provider, 'bundled_vosk');
    expect(availability.dedicatedAndroidAvailable, isFalse);
    expect(availability.bundledOfflineAvailable, isTrue);
  });

  test('starts and returns only the in-memory transcript result', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'startListening' => true,
            'stopListening' => <String, dynamic>{
              'transcript': 'turn mobile mode on',
              'confidence': 0.88,
            },
            _ => null,
          };
        });

    await service.startListening(locale: 'en-PK');
    final result = await service.stopListening();

    expect(calls.map((call) => call.method), [
      'startListening',
      'stopListening',
    ]);
    expect(calls.first.arguments, {'locale': 'en-PK'});
    expect(result.transcript, 'turn mobile mode on');
    expect(result.confidence, closeTo(0.88, 0.001));
  });

  test(
    'preserves native unavailable error without a remote fallback',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'on_device_unavailable',
              message: 'Offline speech is not installed.',
            );
          });

      expect(
        () => service.startListening(locale: 'en-US'),
        throwsA(
          isA<OnDeviceSpeechRecognitionException>()
              .having((error) => error.code, 'code', 'on_device_unavailable')
              .having(
                (error) => error.message,
                'message',
                'Offline speech is not installed.',
              ),
        ),
      );
    },
  );
}
