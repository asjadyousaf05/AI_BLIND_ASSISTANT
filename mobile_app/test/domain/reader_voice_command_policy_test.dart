import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/services/intelligent_intent_resolver.dart';
import 'package:ai_blind_assistant/domain/services/reader_voice_command_policy.dart';

void main() {
  final resolver = IntelligentIntentResolver();
  for (final phrase in [
    'stop reading',
    'pause reading',
    'read again',
    'read first line',
    'read last line',
    'next line',
    'previous line',
    'repeat sentence',
    'spell out',
    'study mode',
    'normal speed',
    'fast mode',
    'speed up',
    'slow down',
    'go to line two',
  ]) {
    test('allows an explicit reader interruption: $phrase', () {
      expect(
        ReaderVoiceCommandPolicy.allowsImmediate(
          resolver.resolve(phrase, context: VoiceFeatureContext.scannerReading),
        ),
        isTrue,
      );
    });
  }
  for (final phrase in [
    'stop',
    'pause',
    'open settings',
    'restart scanner',
    'scan again',
    'confirm',
    'connect raspberry pi',
    'turn flashlight on',
    'goodbye',
    'please describe what the sentence means',
  ]) {
    test('requires ordinary final recognition: $phrase', () {
      expect(
        ReaderVoiceCommandPolicy.allowsImmediate(
          resolver.resolve(phrase, context: VoiceFeatureContext.scannerReading),
        ),
        isFalse,
      );
    });
  }
}
