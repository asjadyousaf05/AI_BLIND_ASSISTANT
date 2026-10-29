import 'dart:async';
import 'dart:io';
import 'package:ai_blind_assistant/domain/entities/smart_ai_cloud_configuration.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_controller.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'package:ai_blind_assistant/domain/enums/microphone_permission_status.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_cloud_service.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_interaction_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';
import 'assistant_controller_test.dart' show FakeMicrophonePermissionService;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late List<String> events;
  late FakeSmartAiConfigurationRepository configuration;
  late FakeSmartAiRecorder recorder;
  late FakeSmartAiService service;
  late FakeSmartAiAudioCoordinator audio;
  late FakeMicrophonePermissionService permission;
  late ProviderContainer container;
  late SmartAiCloudController controller;
  SmartAiCloudState state() => container.read(smartAiCloudControllerProvider);
  Future<void> useDeadlines({
    Duration recordingLimit = const Duration(seconds: 30),
    Duration turnTimeout = const Duration(seconds: 45),
  }) async {
    await controller.deactivate();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    container = ProviderContainer(
      overrides: [
        smartAiCloudControllerProvider.overrideWith(
          () => SmartAiCloudController(
            recordingLimit: recordingLimit,
            turnTimeout: turnTimeout,
          ),
        ),
        smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
          configuration,
        ),
        smartAiCloudServiceProvider.overrideWithValue(service),
        smartAiAudioRecorderProvider.overrideWithValue(recorder),
        smartAiAudioCoordinatorProvider.overrideWithValue(audio),
        microphonePermissionServiceProvider.overrideWithValue(permission),
      ],
    );
    controller = container.read(smartAiCloudControllerProvider.notifier);
    await controller.loadConfiguration();
    await controller.activate();
    events.clear();
  }

  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    directory = await Directory.systemTemp.createTemp('smart-ai-test-');
    events = [];
    configuration = FakeSmartAiConfigurationRepository()
      ..configuration = testSmartAiConfiguration;
    recorder = FakeSmartAiRecorder(directory, events);
    service = FakeSmartAiService(events);
    audio = FakeSmartAiAudioCoordinator(events);
    permission = FakeMicrophonePermissionService();
    container = ProviderContainer(
      overrides: [
        smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
          configuration,
        ),
        smartAiCloudServiceProvider.overrideWithValue(service),
        smartAiAudioRecorderProvider.overrideWithValue(recorder),
        smartAiAudioCoordinatorProvider.overrideWithValue(audio),
        microphonePermissionServiceProvider.overrideWithValue(permission),
      ],
    );
    controller = container.read(smartAiCloudControllerProvider.notifier);
    await controller.loadConfiguration();
    await controller.activate();
    events.clear();
  });
  tearDown(() async {
    await controller.deactivate();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await directory.delete(recursive: true);
  });

  test(
    'fresh-phone local mode never initializes a recorder or cloud client',
    () async {
      final localEvents = <String>[];
      final localAudio = FakeSmartAiAudioCoordinator(localEvents);
      final fresh = ProviderContainer(
        overrides: [
          smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
            FakeSmartAiConfigurationRepository(),
          ),
          smartAiCloudServiceProvider.overrideWith(
            (_) => throw StateError('Cloud client before opt-in'),
          ),
          smartAiAudioRecorderProvider.overrideWith(
            (_) => throw StateError('Recorder before opt-in'),
          ),
          smartAiAudioCoordinatorProvider.overrideWithValue(localAudio),
        ],
      );
      final freshController = fresh.read(
        smartAiCloudControllerProvider.notifier,
      );
      await freshController.activate();
      expect(fresh.read(smartAiCloudControllerProvider).ready, true);
      expect(localEvents, ['acquire']);
      localEvents.clear();
      await freshController.startRecording();
      await freshController.beginHold();
      await freshController.endHold();
      await freshController.sendText('A question must wait for opt-in');
      expect(localEvents, isEmpty);
      await freshController.speakGuide();
      expect(localAudio.spoken.single, contains('Questions stay disabled'));
      await freshController.testListeningCue();
      expect(localAudio.recordingCues, 1);
      await freshController.deactivate();
      expect(localEvents, contains('release'));
      fresh.dispose();
    },
  );

  test(
    'reentering waits for previous local audio restoration before acquisition',
    () async {
      audio.releaseGate = Completer<void>();
      final leaving = controller.deactivate();
      while (!events.contains('release')) {
        await Future<void>.delayed(Duration.zero);
      }
      final entering = controller.activate();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, 'release');
      audio.releaseGate!.complete();
      await leaving;
      await entering;
      expect(events.last, 'acquire');
      expect(state().ready, true);
    },
  );

  test(
    'recording cap automatically submits exactly one sequential turn',
    () async {
      await useDeadlines(recordingLimit: const Duration(milliseconds: 15));
      await controller.startRecording();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(events.where((e) => e == 'transcribe').length, 1);
      expect(state().phase, SmartAiPhase.idle);
      expect(await File(recorder.lastPath!).exists(), false);
    },
  );

  test(
    'whole-turn deadline cancels a stalled provider and ignores its late answer',
    () async {
      await useDeadlines(turnTimeout: const Duration(milliseconds: 15));
      service.replyGate = Completer<String>();
      final turn = controller.sendText('A question');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(state().phase, SmartAiPhase.failed);
      expect(state().error, contains('timed out'));
      service.replyGate!.complete('Too late');
      await turn;
      expect(audio.spoken, isEmpty);
    },
  );

  test('pending credential restore cannot undo explicit key removal', () async {
    final gate = Completer<SmartAiCloudConfiguration?>();
    final repository = FakeSmartAiConfigurationRepository()..loadGate = gate;
    final other = ProviderContainer(
      overrides: [
        smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
    final notifier = other.read(smartAiCloudControllerProvider.notifier);
    await notifier.removeConfiguration();
    gate.complete(testSmartAiConfiguration);
    await notifier.loadConfiguration();
    expect(other.read(smartAiCloudControllerProvider).configuration, isNull);
    other.dispose();
  });

  test(
    'one turn records, transcribes, routes, answers, speaks and deletes audio',
    () async {
      await controller.startRecording();
      expect(state().phase, SmartAiPhase.recording);
      await controller.stopAndSubmit();
      expect(events, [
        'acquire',
        'record',
        'stop-record',
        'transcribe',
        'local',
        'reply',
        'speak',
      ]);
      expect(audio.spoken, ['A brief synthetic answer.']);
      expect(state().phase, SmartAiPhase.idle);
      expect(await File(recorder.lastPath!).exists(), isFalse);
      expect(state().messages.length, 2);
    },
  );

  test(
    'leaving during audio acquisition restores ownership after late setup',
    () async {
      await controller.deactivate();
      events.clear();
      audio.acquireGate = Completer<void>();
      final entering = controller.activate();
      await Future<void>.delayed(Duration.zero);
      final leaving = controller.deactivate();
      audio.acquireGate!.complete();
      await entering;
      await leaving;
      expect(state().ready, false);
      expect(events.last, 'release');
    },
  );

  test(
    'clip is deleted as soon as Groq completes, before LLM finishes',
    () async {
      service.replyGate = Completer<String>();
      await controller.startRecording();
      final turn = controller.stopAndSubmit();
      while (!events.contains('reply')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await File(recorder.lastPath!).exists(), isFalse);
      expect(audio.spoken, isEmpty);
      service.replyGate!.complete('Done.');
      await turn;
    },
  );

  test(
    'speech transcription failure deletes audio and never calls the LLM',
    () async {
      service.transcriptionFailure = const SmartAiCloudException(
        'Groq timed out.',
      );
      await controller.startRecording();
      await controller.stopAndSubmit();
      expect(await File(recorder.lastPath!).exists(), isFalse);
      expect(events, isNot(contains('reply')));
      expect(audio.spoken, isEmpty);
      expect(state().error, 'Groq timed out.');
    },
  );

  test(
    'duplicate record, send and typed presses never overlap a turn',
    () async {
      service.transcriptionGate = Completer<String>();
      await controller.startRecording();
      await controller.startRecording();
      final turn = controller.stopAndSubmit();
      await controller.stopAndSubmit();
      await controller.sendText('Do not overlap');
      while (!events.contains('transcribe')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(events.where((e) => e == 'record').length, 1);
      service.transcriptionGate!.complete('Question');
      await turn;
      expect(events.where((e) => e == 'reply').length, 1);
    },
  );

  test(
    'cancelling transcription suppresses its late transcript and answer',
    () async {
      service.transcriptionGate = Completer<String>();
      await controller.startRecording();
      final turn = controller.stopAndSubmit();
      while (!events.contains('transcribe')) {
        await Future<void>.delayed(Duration.zero);
      }
      await controller.cancel();
      service.transcriptionGate!.complete('Too late');
      await turn;
      expect(events, isNot(contains('reply')));
      expect(audio.spoken, isEmpty);
      expect(await File(recorder.lastPath!).exists(), isFalse);
    },
  );

  test(
    'backgrounding cancels cloud work and never speaks a late answer',
    () async {
      service.replyGate = Completer<String>();
      final turn = controller.sendText('Question');
      while (!events.contains('reply')) {
        await Future<void>.delayed(Duration.zero);
      }
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      service.replyGate!.complete('Too late');
      await turn;
      expect(audio.spoken, isEmpty);
      expect(state().ready, isFalse);
      expect(service.cancellations, greaterThan(0));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(state().ready, isTrue);
    },
  );

  test('background outside Smart AI does not stop Vision AI audio', () async {
    await controller.deactivate();
    events.clear();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test(
    'local app controls bypass AgentRouter and are never parsed from replies',
    () async {
      audio.localResult = 'Local command handled.';
      await controller.sendText('Battery status');
      expect(events, ['local']);
      expect(state().messages.last.text, 'Local command handled.');
      audio.localResult = null;
      await controller.sendText('A general question');
      expect(audio.routed, ['Battery status', 'A general question']);
    },
  );

  test('denied microphone permission never captures or uploads', () async {
    permission.status = MicrophonePermissionStatus.denied;
    await controller.startRecording();
    expect(events, isEmpty);
    expect(state().phase, SmartAiPhase.failed);
    expect(state().error, contains('Microphone permission'));
  });

  test('LLM failure never fabricates or speaks a response', () async {
    service.replyFailure = const SmartAiCloudException(
      'AgentRouter quota reached.',
    );
    await controller.sendText('Question');
    expect(state().error, contains('quota'));
    expect(audio.spoken, isEmpty);
  });

  test(
    'TTS failure preserves the visible answer and offers recovery',
    () async {
      audio.failSpeech = true;
      await controller.sendText('Question');
      expect(state().phase, SmartAiPhase.failed);
      expect(state().messages.last.text, 'A brief synthetic answer.');
    },
  );

  test(
    'changing provider keys while a request is running is refused',
    () async {
      service.replyGate = Completer<String>();
      final turn = controller.sendText('Question');
      expect(await controller.configure(testSmartAiConfiguration), isNotNull);
      expect(await controller.removeConfiguration(), isNotNull);
      service.replyGate!.complete('Done.');
      await turn;
    },
  );

  test(
    'replaying after TTS failure reuses the answer without API or control routing',
    () async {
      audio.failSpeech = true;
      await controller.sendText('Question');
      expect(state().phase, SmartAiPhase.failed);
      events.clear();
      audio.failSpeech = false;
      await controller.repeatLastAnswer();
      expect(events, ['speak']);
      expect(audio.spoken.last, state().messages.last.text);
      expect(state().phase, SmartAiPhase.idle);
      expect(state().error, isNull);
      await controller.deactivate();
      events.clear();
      await controller.repeatLastAnswer();
      expect(events, isEmpty);
    },
  );

  test('removing cloud credentials clears only its own conversation', () async {
    await controller.sendText('Question');
    await controller.removeConfiguration();
    expect(configuration.configuration, isNull);
    expect(state().configuration, isNull);
    expect(state().messages, isEmpty);
  });

  test(
    'hold gives a ready cue and releases exactly one sequential request',
    () async {
      await controller.beginHold();
      expect(state().phase, SmartAiPhase.recording);
      expect(audio.recordingCues, 1);
      await controller.endHold();
      await controller.endHold();
      expect(events.where((e) => e == 'transcribe').length, 1);
      expect(events.where((e) => e == 'reply').length, 1);
      expect(state().phase, SmartAiPhase.idle);
    },
  );

  test(
    'release before microphone setup completes deletes capture without upload',
    () async {
      audio.acquireGate = Completer<void>();
      final starting = controller.beginHold();
      final released = controller.endHold();
      audio.acquireGate!.complete();
      await Future.wait([starting, released]);
      expect(events, isNot(contains('transcribe')));
      expect(recorder.isRecording, false);
      if (recorder.lastPath != null) {
        expect(await File(recorder.lastPath!).exists(), false);
      }
    },
  );

  test('cancelled hold never sends its audio', () async {
    await controller.beginHold();
    await controller.cancelHold();
    await controller.endHold();
    expect(events, isNot(contains('transcribe')));
    expect(await File(recorder.lastPath!).exists(), false);
  });

  test(
    'pause and resume reuse the in-flight reply without a network call',
    () async {
      audio.speechGate = Completer<void>();
      final turn = controller.sendText('A question');
      while (!events.contains('speak')) {
        await Future<void>.delayed(Duration.zero);
      }
      await controller.toggleSpeechPause();
      expect(state().phase, SmartAiPhase.paused);
      await controller.toggleSpeechPause();
      expect(state().phase, SmartAiPhase.speaking);
      expect(events.where((e) => e == 'reply').length, 1);
      expect(events.where((e) => e == 'pause').length, 1);
      expect(events.where((e) => e == 'resume').length, 1);
      audio.speechGate!.complete();
      await turn;
      expect(state().phase, SmartAiPhase.idle);
    },
  );

  test(
    'holding during a reply cancels speech before starting a new recording',
    () async {
      audio.speechGate = Completer<void>();
      final old = controller.sendText('A question');
      while (!events.contains('speak')) {
        await Future<void>.delayed(Duration.zero);
      }
      await controller.beginHold();
      await old;
      expect(state().phase, SmartAiPhase.recording);
      expect(events.indexOf('stop'), lessThan(events.indexOf('record')));
      await controller.cancelHold();
    },
  );

  for (final goodbye in [
    'Goodbye Smart AI.',
    'good bye smart ai',
    'خدا حافظ سمارٹ اے آئی',
  ]) {
    test(
      'exact goodbye releases local audio before requesting Home: $goodbye',
      () async {
        audio.releaseGate = Completer<void>();
        final turn = controller.sendText(goodbye);
        while (!events.contains('release')) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(state().returnHomeRequested, false);
        audio.releaseGate!.complete();
        await turn;
        expect(state().returnHomeRequested, true);
        expect(events, isNot(contains('reply')));
      },
    );
  }
  test('quoted or incidental goodbye does not navigate', () async {
    await controller.sendText('How do I say goodbye Smart AI in Urdu?');
    expect(state().returnHomeRequested, false);
    expect(events, contains('reply'));
  });

  test(
    'recorded goodbye deletes its clip and returns Home without a reply call',
    () async {
      service.transcript = 'goodbye smart ai';
      await controller.beginHold();
      await controller.endHold();
      expect(await File(recorder.lastPath!).exists(), false);
      expect(events, contains('transcribe'));
      expect(events, isNot(contains('reply')));
      expect(state().returnHomeRequested, true);
    },
  );

  test('release after held duration cap never submits twice', () async {
    await useDeadlines(recordingLimit: const Duration(milliseconds: 15));
    service.replyGate = Completer<String>();
    await controller.beginHold();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await controller.endHold();
    // The tap recognizer cancels its competing hold before delivering a tap.
    // A finished capped hold must no longer own the running answer.
    await controller.cancelHold();
    expect(state().phase, SmartAiPhase.thinking);
    expect(events.where((event) => event == 'transcribe').length, 1);
    service.replyGate!.complete('An answer.');
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, SmartAiPhase.idle);
  });
  test(
    'local goodbye exits without a hold, recording, transcription or answer',
    () async {
      audio.goodbyeEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(state().returnHomeRequested, true);
      expect(events, isNot(contains('record')));
      expect(events, isNot(contains('transcribe')));
      expect(events, isNot(contains('reply')));
      expect(events.last, 'release');
    },
  );

  test('local goodbye is ignored during explicit microphone capture', () async {
    await controller.beginHold();
    audio.goodbyeEvents.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, SmartAiPhase.recording);
    expect(state().returnHomeRequested, false);
    await controller.cancel();
  });

  test(
    'selected speech language is frozen for transcription and its answer',
    () async {
      controller.setSpeechLanguage(SmartAiSpeechLanguage.english);
      await controller.beginHold();
      controller.setSpeechLanguage(SmartAiSpeechLanguage.urdu);
      await controller.endHold();
      expect(service.transcriptionLanguage, SmartAiSpeechLanguage.english);
      expect(service.replyLanguage, SmartAiSpeechLanguage.english);
    },
  );

  test(
    'spoken help is local, pausable and does not enter conversation history',
    () async {
      audio.speechGate = Completer<void>();
      final guide = controller.speakGuide();
      await Future<void>.delayed(Duration.zero);
      expect(state().speechIsGuide, true);
      await controller.toggleSpeechPause();
      expect(state().phase, SmartAiPhase.paused);
      await controller.toggleSpeechPause();
      audio.speechGate!.complete();
      await guide;
      expect(state().messages, isEmpty);
      expect(events, isNot(contains('reply')));
      expect(audio.spoken.single, contains('lift your finger'));
    },
  );
  test(
    'ready feedback fires only after the native microphone is recording',
    () async {
      audio.onRecordingCue = () {
        expect(recorder.isRecording, true);
        expect(state().phase, SmartAiPhase.recording);
      };
      await controller.beginHold();
      expect(audio.recordingCues, 1);
      final stops = audio.cueStops;
      await controller.cancelHold();
      expect(audio.cueStops, greaterThan(stops));
      expect(events, isNot(contains('transcribe')));
    },
  );

  test(
    'cue failure leaves recording usable and exposes its fallback guidance',
    () async {
      audio.cueFailure = const SmartAiCloudException(
        'Check media volume; vibration is ready.',
      );
      await controller.beginHold();
      expect(state().phase, SmartAiPhase.recording);
      expect(recorder.isRecording, true);
      expect(state().error, contains('Check media volume'));
      final stops = audio.cueStops;
      await controller.endHold();
      expect(audio.cueStops, greaterThan(stops));
      expect(events.where((event) => event == 'transcribe').length, 1);
    },
  );

  test('test cue uses no recording, transcription or reasoning', () async {
    await controller.testListeningCue();
    expect(audio.recordingCues, 1);
    expect(recorder.isRecording, false);
    expect(state().phase, SmartAiPhase.idle);
    expect(events, isEmpty);
  });

  test(
    'backgrounding cancels the readiness cue and discards capture',
    () async {
      await controller.beginHold();
      final stops = audio.cueStops;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(audio.cueStops, greaterThan(stops));
      expect(recorder.isRecording, false);
      expect(events, isNot(contains('transcribe')));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
}
