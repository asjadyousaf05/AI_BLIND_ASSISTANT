import 'dart:async';

import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/router/app_route_observer.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/domain/enums/voice_runtime_state.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/tts_echo_guard.dart';
import 'package:ai_blind_assistant/domain/services/voice_listening_feedback.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_controller_test.dart'
    show
        FakeMicrophonePermissionService,
        FakeOnDeviceSpeechRecognitionService,
        FakeSpeechOutputService;

class _Recognizer extends FakeOnDeviceSpeechRecognitionService
    implements VoiceListeningFeedback {
  int failures = 0;
  int stops = 0;
  int cues = 0;
  bool paused = false;
  bool cueFailure = false;
  Completer<void>? startGate;
  @override
  Future<void> startHandsFree({required String locale}) async {
    await startGate?.future;
    await super.startHandsFree(locale: locale);
    paused = false;
  }

  @override
  Future<void> pauseHandsFree() async {
    paused = true;
  }

  @override
  Future<void> resumeHandsFree({bool acceptNextCommand = false}) async {
    await super.resumeHandsFree(acceptNextCommand: acceptNextCommand);
    if (failures > 0 || !handsFreeListening) {
      if (failures > 0) failures--;
      throw const OnDeviceSpeechRecognitionException(
        'resume_failed',
        'Offline microphone unavailable.',
      );
    }
    paused = false;
  }

  @override
  Future<void> stopHandsFree() async {
    stops++;
    paused = true;
    await super.stopHandsFree();
  }

  @override
  Future<void> playListeningReadyCue() async {
    if (cueFailure) throw StateError('Feedback output unavailable');
    expect(handsFreeListening, true);
    expect(paused, false);
    cues++;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late VisionVoiceKernelV3 kernel;
  late _Recognizer recognizer;
  late FakeSpeechOutputService speech;
  late DateTime now;
  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    appRouteObserver.currentRoute = null;
    now = DateTime(2026, 10, 21);
    recognizer = _Recognizer();
    speech = FakeSpeechOutputService();
    container = ProviderContainer(
      overrides: [
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(recognizer),
        speechOutputServiceProvider.overrideWithValue(speech),
        microphonePermissionServiceProvider.overrideWithValue(
          FakeMicrophonePermissionService(),
        ),
        ttsEchoGuardProvider.overrideWithValue(TtsEchoGuard(clock: () => now)),
        assistantRepositoryProvider.overrideWith(
          (_) => throw StateError('Voice recovery contacted an AI provider'),
        ),
      ],
    );
    kernel = container.read(visionVoiceKernelProvider.notifier);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await recognizer.handsFreeEventController.close();
    appRouteObserver.currentRoute = null;
  });
  Future<void> emit(HandsFreeSpeechEventType type, {String? transcript}) async {
    recognizer.handsFreeEventController.add(
      HandsFreeSpeechEvent(type: type, transcript: transcript),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> wake() => emit(HandsFreeSpeechEventType.wake);

  test('speaker-echo wake cannot leave the native microphone paused', () async {
    final guard = container.read(ttsEchoGuardProvider);
    guard.onTtsStart(
      utteranceId: 'guide',
      sentenceId: 'guide',
      sentenceText: 'Say hey vision ai to begin.',
      generation: 1,
    );
    guard.onTtsStop();
    recognizer.paused = true;
    await wake();
    expect(recognizer.paused, false);
    expect(speech.spokenTexts, isEmpty);
    expect(
      container.read(visionVoiceKernelProvider).runtimeState,
      VoiceRuntimeState.wakeListening,
    );
    now = now.add(const Duration(seconds: 2));
    await wake();
    expect(speech.spokenTexts, ['Listening.']);
    expect(recognizer.acceptNextCommand, true);
    expect(recognizer.cues, 1);
  });

  test(
    'ready cue follows actual resume after feedback, not while speaking',
    () async {
      await wake();
      speech.speechGate = Completer<void>();
      final cues = recognizer.cues;
      final feedback = kernel.speakFeedback('Ready to continue.');
      await Future<void>.delayed(Duration.zero);
      expect(recognizer.paused, true);
      expect(recognizer.cues, cues);
      speech.speechGate!.complete();
      await feedback;
      expect(recognizer.paused, false);
      expect(recognizer.cues, cues + 1);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.commandListening,
      );
    },
  );

  test(
    'one resume failure recovers and retains the active command session',
    () async {
      await wake();
      final starts = recognizer.handsFreeStartCount;
      recognizer.failures = 1;
      await kernel.speakFeedback('Command completed.');
      expect(recognizer.handsFreeStartCount, starts + 1);
      expect(recognizer.paused, false);
      expect(recognizer.acceptNextCommand, true);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.commandListening,
      );
    },
  );

  test(
    'persistent failures stop after two recovery attempts with actionable status',
    () async {
      await wake();
      final starts = recognizer.handsFreeStartCount;
      recognizer.failures = 20;
      await kernel.speakFeedback('Command completed.');
      final state = container.read(visionVoiceKernelProvider);
      expect(recognizer.handsFreeStartCount, starts + 2);
      expect(state.runtimeState, VoiceRuntimeState.error);
      expect(state.isHandsFreeActive, false);
      expect(state.statusMessage, contains('screen buttons'));
      expect(recognizer.handsFreeListening, false);
    },
  );

  test('repeated native errors share a single recovery', () async {
    final starts = recognizer.handsFreeStartCount;
    await emit(HandsFreeSpeechEventType.error);
    await emit(HandsFreeSpeechEventType.error);
    await emit(HandsFreeSpeechEventType.error);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(recognizer.handsFreeStartCount, starts + 1);
    expect(
      container.read(visionVoiceKernelProvider).runtimeState,
      VoiceRuntimeState.wakeListening,
    );
  });

  test(
    'backgrounding cancels pending recovery without restarting the microphone',
    () async {
      final starts = recognizer.handsFreeStartCount;
      await emit(HandsFreeSpeechEventType.error);
      await kernel.pauseVoice();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(recognizer.handsFreeStartCount, starts);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.suspended,
      );
      expect(recognizer.cues, 0);
    },
  );

  test(
    'concurrent starts share one operation and stop invalidates a pending start',
    () async {
      await kernel.stopHandsFree();
      recognizer.startGate = Completer<void>();
      final starts = recognizer.handsFreeStartCount;
      final first = kernel.startHandsFree();
      final second = kernel.startHandsFree();
      await Future<void>.delayed(Duration.zero);
      await kernel.stopHandsFree();
      recognizer.startGate!.complete();
      await Future.wait([first, second]);
      expect(recognizer.handsFreeStartCount, starts + 1);
      expect(recognizer.handsFreeListening, false);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.disabled,
      );
    },
  );

  test(
    'duplicate wake callbacks do not overlap speech or abandon capture',
    () async {
      speech.speechGate = Completer<void>();
      await wake();
      await wake();
      expect(speech.spokenTexts, ['Listening.']);
      speech.speechGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(recognizer.paused, false);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.commandListening,
      );
    },
  );

  test(
    'explicit restart restores listening after bounded recovery fails',
    () async {
      await wake();
      recognizer.failures = 20;
      await kernel.speakFeedback('Command completed.');
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.error,
      );
      recognizer.failures = 0;
      await kernel.restartHandsFree();
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.commandListening,
      );
      expect(recognizer.paused, false);
    },
  );

  test('a failed ready cue does not disable command listening', () async {
    recognizer.cueFailure = true;
    await wake();
    expect(
      container.read(visionVoiceKernelProvider).runtimeState,
      VoiceRuntimeState.commandListening,
    );
    expect(recognizer.paused, false);
  });

  test(
    'empty native command delivery restores capture without executing anything',
    () async {
      await wake();
      recognizer.paused = true;
      await emit(HandsFreeSpeechEventType.command);
      expect(recognizer.paused, false);
      expect(speech.spokenTexts, ['Listening.']);
    },
  );

  test(
    'foreground resume replaces an interrupted pending start once',
    () async {
      await kernel.stopHandsFree();
      recognizer.startGate = Completer<void>();
      final starts = recognizer.handsFreeStartCount;
      final start = kernel.startHandsFree();
      await Future<void>.delayed(Duration.zero);
      for (final phase in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        binding.handleAppLifecycleStateChanged(phase);
      }
      recognizer.startGate!.complete();
      await start;
      await Future<void>.delayed(Duration.zero);
      expect(recognizer.handsFreeStartCount, starts + 2);
      expect(
        container.read(visionVoiceKernelProvider).runtimeState,
        VoiceRuntimeState.wakeListening,
      );
      expect(recognizer.handsFreeListening, true);
    },
  );
}
