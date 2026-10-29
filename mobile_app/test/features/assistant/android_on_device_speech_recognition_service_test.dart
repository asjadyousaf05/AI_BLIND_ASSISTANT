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

  test('resume requires an affirmative native microphone result', () async {
    var ready = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'resumeHandsFree');
          expect(call.arguments, {'acceptNextCommand': true});
          return ready;
        });
    await expectLater(
      service.resumeHandsFree(acceptNextCommand: true),
      throwsA(isA<OnDeviceSpeechRecognitionException>()),
    );
    ready = true;
    await service.resumeHandsFree(acceptNextCommand: true);
  });

  test(
    'resume surfaces platform failures instead of claiming listening',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'resume_failed',
              message: 'Microphone unavailable.',
            );
          });
      await expectLater(
        service.resumeHandsFree(),
        throwsA(
          isA<OnDeviceSpeechRecognitionException>().having(
            (e) => e.code,
            'code',
            'resume_failed',
          ),
        ),
      );
    },
  );

  test(
    'missing resume capability fails while optional ready feedback is harmless',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw MissingPluginException(),
          );
      await expectLater(
        service.resumeHandsFree(),
        throwsA(isA<OnDeviceSpeechRecognitionException>()),
      );
      await service.playListeningReadyCue();
    },
  );

  test(
    'reader candidate claim uses the current native candidate identifier',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'acceptReaderCommandCandidate' &&
                call.arguments['candidateId'] == 'current';
          });
      await service.setReaderPlaybackActive(true);
      expect(await service.acceptReaderCommandCandidate('expired'), isFalse);
      expect(await service.acceptReaderCommandCandidate('current'), isTrue);
      await service.setReaderPlaybackActive(false);
      expect(calls.first.arguments, {'active': true});
      expect(calls.last.arguments, {'active': false});
    },
  );

  test(
    'unsupported reader interruption capability cannot authorize a command',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw MissingPluginException(),
          );
      expect(await service.acceptReaderCommandCandidate('old'), isFalse);
    },
  );

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
  test(
    'Smart AI goodbye bridge emits only while its foreground capability is enabled',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      var count = 0;
      final sub = service.smartAiGoodbyes.listen((_) => count++);
      Future<void> emit() async {
        ServicesBinding.instance.channelBuffers.push(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSmartAiGoodbye'),
          ),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      await emit();
      expect(count, 0);
      await service.setSmartAiControlsActive(true);
      await emit();
      expect(count, 1);
      await service.setSmartAiControlsActive(false);
      await emit();
      expect(count, 1);
      expect(calls.map((c) => c.arguments), [
        {'active': true},
        {'active': false},
      ]);
      await sub.cancel();
    },
  );
}
