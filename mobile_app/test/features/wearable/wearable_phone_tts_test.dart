import 'dart:async';

import 'package:ai_blind_assistant/infrastructure/assistant/flutter_tts_speech_output_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('phone TTS reports a failed platform utterance', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'speak') return 0;
      return 1;
    });
    final speech = FlutterTtsSpeechOutputService();

    await expectLater(speech.speak('Chair ahead'), throwsA(isA<StateError>()));
    expect(speech.isSpeaking, isFalse);
  });

  test('phone TTS completes a successful platform utterance', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 1);
    final speech = FlutterTtsSpeechOutputService();

    await speech.speak('Chair ahead');

    expect(speech.isSpeaking, isFalse);
  });

  testWidgets(
    'slow but successful phone test does not report a false failure',
    (tester) async {
      final native = Completer<int>();
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'speak' ? native.future : 1,
      );
      final speech = FlutterTtsSpeechOutputService();
      final result = speech.speak(
        'Phone audio test. Raspberry Pi object alerts will play on this phone.',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(speech.isSpeaking, isTrue);
      native.complete(1);
      await tester.pump();
      await result;
      expect(speech.isSpeaking, isFalse);
    },
  );

  testWidgets(
    'a missing completion still times out and releases speech ownership',
    (tester) async {
      final native = Completer<int>();
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'speak' ? native.future : 1,
      );
      final speech = FlutterTtsSpeechOutputService();
      final result = expectLater(
        speech.speak('Chair ahead'),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await result;
      expect(speech.isSpeaking, isFalse);
      native.complete(1);
      await tester.pump();
    },
  );
}
