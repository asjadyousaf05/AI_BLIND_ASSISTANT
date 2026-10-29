import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_foreground_recognition.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_reply_speech_service.dart';
import 'package:ai_blind_assistant/domain/services/tts_echo_guard.dart';
import 'assistant_controller_test.dart'
    show
        FakeOnDeviceSpeechRecognitionService,
        FakeMicrophonePermissionService,
        FakeSpeechOutputService;

class _Recognizer extends FakeOnDeviceSpeechRecognitionService
    implements SmartAiForegroundRecognition {
  final goodbyes = StreamController<void>.broadcast();
  bool active = false;
  Completer<void>? startGate;
  @override
  Future<void> startHandsFree({required String locale}) async {
    await startGate?.future;
    await super.startHandsFree(locale: locale);
  }

  @override
  Stream<void> get smartAiGoodbyes => goodbyes.stream;
  @override
  Future<void> setSmartAiControlsActive(bool value) async {
    active = value;
  }
}

class _Speech implements SmartAiReplySpeechService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Recognizer recognizer;
  late ProviderContainer container;
  var now = DateTime(2026, 10, 20);
  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    recognizer = _Recognizer();
    container = ProviderContainer(
      overrides: [
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(recognizer),
        speechOutputServiceProvider.overrideWithValue(
          FakeSpeechOutputService(),
        ),
        smartAiReplySpeechProvider.overrideWithValue(_Speech()),
        microphonePermissionServiceProvider.overrideWithValue(
          FakeMicrophonePermissionService(),
        ),
        ttsEchoGuardProvider.overrideWithValue(TtsEchoGuard(clock: () => now)),
        assistantRepositoryProvider.overrideWith(
          (_) => throw StateError('Unprompted Smart AI request'),
        ),
      ],
    );
    container.read(visionVoiceKernelProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await recognizer.goodbyes.close();
  });
  test(
    'local controls yield the microphone only during button capture',
    () async {
      final audio = container.read(smartAiAudioCoordinatorProvider);
      await audio.acquire();
      expect(recognizer.active, true);
      expect(recognizer.recognitionProfile, 'app_commands');
      expect(recognizer.handsFreeListening, true);
      expect(recognizer.acceptNextCommand, true);
      await audio.prepareRecording();
      expect(recognizer.handsFreeListening, false);
      await audio.recordingFinished();
      expect(recognizer.handsFreeListening, true);
      expect(recognizer.acceptNextCommand, true);
      await audio.release();
      expect(recognizer.active, false);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.unknown,
      );
    },
  );
  test(
    'speaker goodbye echo is rejected and later real local goodbye is accepted',
    () async {
      final audio = container.read(smartAiAudioCoordinatorProvider);
      await audio.acquire();
      var exits = 0;
      final sub = audio.goodbyeRequests.listen((_) => exits++);
      final guard = container.read(ttsEchoGuardProvider);
      guard.onTtsStart(
        utteranceId: 'guide',
        sentenceId: 'guide',
        sentenceText: 'Say goodbye Smart AI to leave.',
        generation: 1,
      );
      recognizer.goodbyes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(exits, 0);
      guard.onTtsStop();
      now = now.add(const Duration(seconds: 2));
      recognizer.goodbyes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(exits, 1);
      await audio.release();
      recognizer.goodbyes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(exits, 1);
      await sub.cancel();
    },
  );
  test(
    'ordinary local speech cannot enter the legacy Smart AI conversation path',
    () async {
      await container.read(smartAiAudioCoordinatorProvider).acquire();
      recognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'What can you tell me about a rainbow',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.smartAi,
      );
      await container.read(smartAiAudioCoordinatorProvider).release();
    },
  );
  test(
    'exit waits for a pending local microphone restart before restoring mode',
    () async {
      final audio = container.read(smartAiAudioCoordinatorProvider);
      await audio.acquire();
      await audio.prepareRecording();
      recognizer.startGate = Completer<void>();
      final restart = audio.recordingFinished();
      var released = false;
      final exit = audio.release().then((_) => released = true);
      await Future<void>.delayed(Duration.zero);
      expect(released, false);
      recognizer.startGate!.complete();
      await Future.wait([restart, exit]);
      expect(released, true);
      expect(recognizer.active, false);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.unknown,
      );
    },
  );
  test(
    'temporary direct Smart AI controls restore a disabled global listener on exit',
    () async {
      container
          .read(appSettingsControllerProvider.notifier)
          .setHandsFreeAssistantEnabled(false);
      final audio = container.read(smartAiAudioCoordinatorProvider);
      await audio.acquire();
      expect(recognizer.acceptNextCommand, true);
      await container
          .read(visionVoiceKernelProvider.notifier)
          .speakFeedback('Local command finished.');
      expect(recognizer.handsFreeListening, true);
      await audio.prepareRecording();
      expect(recognizer.handsFreeListening, false);
      await audio.recordingFinished();
      expect(recognizer.acceptNextCommand, true);
      await audio.pauseSpeech();
      expect(recognizer.acceptNextCommand, true);
      await audio.release();
      expect(recognizer.handsFreeListening, false);
      expect(
        container.read(appSettingsControllerProvider).handsFreeAssistantEnabled,
        false,
      );
    },
  );
}
