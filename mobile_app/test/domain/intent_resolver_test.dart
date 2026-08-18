import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/enums/voice_intent.dart';
import 'package:ai_blind_assistant/domain/services/intelligent_intent_resolver.dart';

void main() {
  late IntelligentIntentResolver resolver;

  setUp(() {
    resolver = IntelligentIntentResolver();
  });

  group('IntelligentIntentResolver - Mobile Detection Intents', () {
    const startVariations = [
      'start mobile mode',
      'start detection',
      'start object detection',
      'start mobile detection',
      'start camera',
      'start seeing',
      'start vision',
      'start mobile assistance',
      'start assistance',
      'start detecting',
      'detect objects',
      'help me see',
      'run detection',
      'begin detection',
      'enable detection',
      'activate detection',
      'turn on detection',
      'look around',
      'start obstacle detection',
      'hey vision ai start mobile mode',
      'vision start detection',
      'hey vision help me see',
    ];

    for (final phrase in startVariations) {
      test('resolves "$phrase" to StartMobileDetection', () {
        final command = resolver.resolve(phrase);
        expect(
          command.intent,
          isA<StartMobileDetection>(),
          reason: 'Failed for: "$phrase"',
        );
        expect(command.matchScore, greaterThanOrEqualTo(0.5));
      });
    }

    const stopVariations = [
      'stop mobile mode',
      'stop detection',
      'stop the detection',
      'stop detecting',
      'stop camera',
      'stop vision',
      'stop seeing',
      'stop mobile assistance',
      'stop model',
      'stop phone mode',
      'stop object detection',
      'turn off detection',
      'turn off camera',
      'turn off vision',
      'turn off mobile mode',
      'turn off assistance',
      'end detection',
      'close detection',
      'exit detection',
      'kill detection',
      'deactivate detection',
      'disable detection',
      'vision stop detection',
      'hey vision turn off camera',
    ];

    for (final phrase in stopVariations) {
      test('resolves "$phrase" to StopMobileDetection', () {
        final command = resolver.resolve(phrase);
        expect(
          command.intent,
          isA<StopMobileDetection>(),
          reason: 'Failed for: "$phrase"',
        );
      });
    }

    test('resolves bare "stop" to StopMobileDetection when in mobileDetection context', () {
      final command = resolver.resolve(
        'stop',
        context: VoiceFeatureContext.mobileDetection,
      );
      expect(command.intent, isA<StopMobileDetection>());
    });

    test('resolves bare "stop" to Silence when in scannerReading context', () {
      final command = resolver.resolve(
        'stop',
        context: VoiceFeatureContext.scannerReading,
      );
      expect(command.intent, isA<Silence>());
    });
  });

  group('IntelligentIntentResolver - Document Scanner & Reader Intents', () {
    test('resolves scan commands and natural variations', () {
      expect(resolver.resolve('scan document').intent, isA<ScanDocument>());
      expect(resolver.resolve('scan this document').intent, isA<ScanDocument>());
      expect(resolver.resolve('scan this page').intent, isA<ScanDocument>());
      expect(resolver.resolve('take photo').intent, isA<ScanDocument>());
      expect(resolver.resolve('take a photo').intent, isA<ScanDocument>());
      expect(resolver.resolve('take picture').intent, isA<ScanDocument>());
      expect(resolver.resolve('take a picture').intent, isA<ScanDocument>());
      expect(resolver.resolve('read this').intent, isA<ScanDocument>());
      expect(resolver.resolve('read this document').intent, isA<ScanDocument>());
      expect(resolver.resolve('read page').intent, isA<ScanDocument>());
      expect(resolver.resolve('read this page').intent, isA<ScanDocument>());
      expect(resolver.resolve('read the text').intent, isA<ScanDocument>());
      expect(resolver.resolve('capture').intent, isA<ScanDocument>());
      expect(resolver.resolve('capture page').intent, isA<ScanDocument>());
      expect(resolver.resolve('capture this page').intent, isA<ScanDocument>());
      expect(resolver.resolve('capture document').intent, isA<ScanDocument>());
      expect(resolver.resolve('rescan').intent, isA<RescanDocument>());
      expect(resolver.resolve('scan again').intent, isA<RescanDocument>());
      expect(resolver.resolve('scan another page').intent, isA<RescanDocument>());
      expect(resolver.resolve('new scan').intent, isA<RescanDocument>());
      expect(resolver.resolve('read again').intent, isA<ReadDocumentAgain>());
    });

    test('resolves natural polite phrases with prefixes', () {
      expect(
        resolver.resolve('Vision, could you please read that sentence again?').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('Vision, can you go back one sentence?').intent,
        isA<ReadingPrevious>(),
      );
      expect(
        resolver.resolve('Vision, please make the reading slower.').intent,
        isA<SetReadingProfile>(),
      );
      expect(
        resolver.resolve('could you repeat that').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('can you repeat that').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('what did you just say').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('say that again').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('read that again').intent,
        isA<ReadingRepeat>(),
      );
      expect(
        resolver.resolve('read that sentence again').intent,
        isA<ReadingRepeat>(),
      );
    });

    test('resolves reader playback controls', () {
      expect(resolver.resolve('pause reading').intent, isA<ReadingPause>());
      expect(resolver.resolve('pause it').intent, isA<ReadingPause>());
      expect(resolver.resolve('pause the reading').intent, isA<ReadingPause>());
      expect(resolver.resolve('hold on').intent, isA<ReadingPause>());
      expect(resolver.resolve('wait a moment').intent, isA<ReadingPause>());
      expect(resolver.resolve('resume reading').intent, isA<ReadingResume>());
      expect(resolver.resolve('continue reading').intent, isA<ReadingResume>());
      expect(resolver.resolve('keep reading').intent, isA<ReadingResume>());
      expect(resolver.resolve('start reading again').intent, isA<ReadingResume>());
      expect(resolver.resolve('next sentence').intent, isA<ReadingNext>());
      expect(resolver.resolve('go next').intent, isA<ReadingNext>());
      expect(resolver.resolve('move to next sentence').intent, isA<ReadingNext>());
      expect(resolver.resolve('read the next sentence').intent, isA<ReadingNext>());
      expect(resolver.resolve('previous sentence').intent, isA<ReadingPrevious>());
      expect(resolver.resolve('go back one sentence').intent, isA<ReadingPrevious>());
      expect(resolver.resolve('read the previous sentence').intent, isA<ReadingPrevious>());
      expect(resolver.resolve('repeat sentence').intent, isA<ReadingRepeat>());
      expect(resolver.resolve('repeat this sentence').intent, isA<ReadingRepeat>());
      expect(resolver.resolve('repeat current sentence').intent, isA<ReadingRepeat>());
      expect(resolver.resolve('restart reading').intent, isA<ReadingRestart>());
      expect(resolver.resolve('start from the beginning').intent, isA<ReadingRestart>());
      expect(resolver.resolve('spell word').intent, isA<ReadingSpell>());
      expect(resolver.resolve('spell this word').intent, isA<ReadingSpell>());
      expect(resolver.resolve('spell current word').intent, isA<ReadingSpell>());
      expect(resolver.resolve('spell sentence').intent, isA<ReadingSpell>());
      expect(resolver.resolve('spell this sentence').intent, isA<ReadingSpell>());
      expect(resolver.resolve('copy document').intent, isA<CopyScannedText>());
      expect(resolver.resolve('copy all text').intent, isA<CopyScannedText>());
      expect(resolver.resolve('copy everything').intent, isA<CopyScannedText>());
    });

    test('resolves reading speed profiles', () {
      final study = resolver.resolve('study mode');
      expect(study.intent, isA<SetReadingProfile>());
      expect((study.intent as SetReadingProfile).profile, 'learning');

      final slow = resolver.resolve('make it slower');
      expect(slow.intent, isA<SetReadingProfile>());
      expect((slow.intent as SetReadingProfile).profile, 'learning');

      final fast = resolver.resolve('fast mode');
      expect(fast.intent, isA<SetReadingProfile>());
      expect((fast.intent as SetReadingProfile).profile, 'skim');

      final faster = resolver.resolve('make it faster');
      expect(faster.intent, isA<SetReadingProfile>());
      expect((faster.intent as SetReadingProfile).profile, 'skim');

      final normal = resolver.resolve('normal speed');
      expect(normal.intent, isA<SetReadingProfile>());
      expect((normal.intent as SetReadingProfile).profile, 'normal');
    });
  });

  group('IntelligentIntentResolver - Settings and Disambiguation', () {
    test('resolves sensitivity with synonyms (confidence, accuracy)', () {
      final low = resolver.resolve('decrease sensitivity');
      expect(low.intent, isA<SetDetectionSensitivity>());
      expect((low.intent as SetDetectionSensitivity).level, 'low');

      final high = resolver.resolve('increase confidence');
      expect(high.intent, isA<SetDetectionSensitivity>());
      expect((high.intent as SetDetectionSensitivity).level, 'high');

      final normal = resolver.resolve('normal accuracy');
      expect(normal.intent, isA<SetDetectionSensitivity>());
      expect((normal.intent as SetDetectionSensitivity).level, 'medium');
    });

    test('resolves feedback modes', () {
      final vibe = resolver.resolve('feedback mode vibration');
      expect(vibe.intent, isA<SetFeedbackMode>());
      expect((vibe.intent as SetFeedbackMode).mode, 'vibration');

      final both = resolver.resolve('feedback mode audio and vibration');
      expect(both.intent, isA<SetFeedbackMode>());
      expect((both.intent as SetFeedbackMode).mode, 'both');
    });

    test('resolves accessibility boolean settings', () {
      final large = resolver.resolve('turn on large text');
      expect(large.intent, isA<SetBooleanSetting>());
      final largeSetting = large.intent as SetBooleanSetting;
      expect(largeSetting.setting, 'large_text');
      expect(largeSetting.enabled, isTrue);

      final contrast = resolver.resolve('disable high contrast');
      expect(contrast.intent, isA<SetBooleanSetting>());
      final contrastSetting = contrast.intent as SetBooleanSetting;
      expect(contrastSetting.setting, 'high_contrast');
      expect(contrastSetting.enabled, isFalse);
    });

    test('resolves navigation commands', () {
      expect(resolver.resolve('open settings').intent, isA<NavigateSettings>());
      expect(resolver.resolve('go home').intent, isA<NavigateHome>());
      expect(resolver.resolve('open scanner').intent, isA<NavigateScanner>());
      expect(resolver.resolve('talk to smart ai').intent, isA<NavigateSmartAi>());
      expect(resolver.resolve('go back').intent, isA<NavigateBack>());
    });

    test('resolves emergency stop', () {
      expect(resolver.resolve('stop everything').intent, isA<EmergencyStop>());
      expect(resolver.resolve('emergency stop').intent, isA<EmergencyStop>());
      expect(resolver.resolve('halt everything').intent, isA<EmergencyStop>());
    });
  });

  group('IntelligentIntentResolver - Negative Tests (Non-command rejection)', () {
    test('rejects empty and nonsense tokens', () {
      expect(resolver.resolve('').intent, isA<UnknownIntent>());
      expect(resolver.resolve('[unk]').intent, isA<UnknownIntent>());
      expect(resolver.resolve('unk').intent, isA<UnknownIntent>());
      expect(resolver.resolve('huh').intent, isA<UnknownIntent>());
    });

    test('standalone wake phrase produces Greeting', () {
      final cmd = resolver.resolve('hey vision ai');
      expect(cmd.intent, isA<Greeting>());
    });
  });
}
