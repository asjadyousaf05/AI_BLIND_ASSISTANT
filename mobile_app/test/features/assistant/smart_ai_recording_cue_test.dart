import 'package:ai_blind_assistant/domain/services/smart_ai_cloud_service.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/smart_ai_recording_cue.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_blind_assistant/smart_ai_recording_cue');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'requests both native cues locally without payloads or duplicate play',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {'vibrationStarted': true, 'chimeStarted': true};
      });
      final cue = SmartAiRecordingCue();
      await cue.play();
      await cue.stop();
      expect(calls.map((c) => c.method), ['play', 'stop']);
      expect(calls.every((c) => c.arguments == null), true);
    },
  );

  for (final result in [
    {'vibrationStarted': false, 'chimeStarted': true},
    {'vibrationStarted': true, 'chimeStarted': false},
    {'vibrationStarted': false, 'chimeStarted': false},
  ]) {
    test('reports available fallback accurately for $result', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => result);
      await expectLater(
        SmartAiRecordingCue().play(),
        throwsA(
          isA<SmartAiCloudException>().having(
            (e) => e.message,
            'guidance',
            contains(
              result['vibrationStarted']!
                  ? 'Check media volume'
                  : result['chimeStarted']!
                  ? 'The chime'
                  : 'Button controls',
            ),
          ),
        ),
      );
    });
  }

  test(
    'cancellation remains safe if the native output is unavailable',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await SmartAiRecordingCue().stop();
    },
  );
}
