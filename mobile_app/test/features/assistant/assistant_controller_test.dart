import '../../helpers/gemini_fakes.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_blind_assistant/app/assistance_controller.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/assistant_session_controller.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/app/router/app_route_observer.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_response.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_tool_result.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_failure_kind.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_backend_status.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_session_state.dart';
import 'package:ai_blind_assistant/domain/enums/detection_sensitivity.dart';
import 'package:ai_blind_assistant/domain/enums/microphone_permission_status.dart';
import 'package:ai_blind_assistant/domain/enums/mobile_assistance_state.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/enums/voice_intent.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_credential_repository.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_repository.dart';
import 'package:ai_blind_assistant/domain/services/microphone_permission_service.dart';
import 'package:ai_blind_assistant/domain/services/audio_recorder_service.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class FakeAssistantCredentialRepository
    implements AssistantCredentialRepository {
  AssistantCredential? credential;
  Completer<AssistantCredential?>? loadGate;
  int loadCount = 0;

  @override
  Future<AssistantCredential?> loadCredential() async {
    loadCount++;
    return loadGate == null ? credential : await loadGate!.future;
  }

  @override
  Future<void> saveCredential(AssistantCredential cred) async {
    credential = cred;
  }

  @override
  Future<void> deleteCredential() async {
    credential = null;
  }

  @override
  Future<bool> hasPairedCredential() async => credential?.isValid ?? false;
}

class FakeAssistantRepository implements AssistantRepository {
  bool isReachable = true;
  int serverVersion = 1;
  AssistantResponse? nextTextResponse;
  AssistantResponse? nextAudioResponse;
  List<AssistantMessage> history = [];
  int textQueryCount = 0;
  final List<AssistantToolResult> reportedResults = [];
  bool failToolReport = false;
  int healthCheckCount = 0;
  Completer<int?>? healthGate;
  Object? healthFailure;
  AssistantNetworkException? audioFailure;

  @override
  Future<int?> checkHealth(AssistantCredential credential) async {
    healthCheckCount++;
    if (healthFailure case final error?) throw error;
    if (healthGate case final gate?) return gate.future;
    return isReachable ? serverVersion : null;
  }

  @override
  Future<AssistantCredential> pair({
    required String backendUrl,
    required String pairingCode,
  }) async {
    if (pairingCode == 'BADCODE') {
      throw const AssistantAuthException('Invalid pairing code');
    }
    return AssistantCredential(
      backendUrl: backendUrl,
      bearerToken: 'fake_bearer_token_123',
      userId: 'test_user_id',
      displayName: 'User',
      pairedAt: DateTime.now(),
      protocolVersion: serverVersion,
    );
  }

  @override
  Future<AssistantResponse> sendTextQuery({
    required AssistantCredential credential,
    required String query,
    required List<AssistantMessage> conversationHistory,
  }) async {
    textQueryCount += 1;
    if (!isReachable) {
      throw const AssistantNetworkException('Backend unreachable');
    }
    return nextTextResponse ??
        AssistantResponse(responseText: 'Echo: $query', requestId: 'req_1');
  }

  @override
  Future<AssistantResponse> sendAudioQuery({
    required AssistantCredential credential,
    required String audioFilePath,
    required List<AssistantMessage> conversationHistory,
  }) async {
    if (audioFailure case final error?) throw error;
    if (!isReachable) {
      throw const AssistantNetworkException('Backend unreachable');
    }
    return nextAudioResponse ??
        const AssistantResponse(
          responseText: 'Audio processed successfully.',
          requestId: 'req_audio_1',
        );
  }

  @override
  Future<AssistantResponse> reportToolResult({
    required AssistantCredential credential,
    required String requestId,
    required AssistantToolResult result,
    required List<AssistantMessage> conversationHistory,
  }) async {
    reportedResults.add(result);
    if (failToolReport) {
      throw const AssistantNetworkException('Test connection lost');
    }
    return const AssistantResponse(
      responseText: 'Tool result processed.',
      requestId: 'req_tool_1',
    );
  }

  @override
  Future<List<AssistantMessage>> loadConversationHistory(
    AssistantCredential credential, {
    int limit = 20,
  }) async => history;

  @override
  Future<void> clearConversationHistory(AssistantCredential credential) async {
    history.clear();
  }

  @override
  Future<List<Map<String, dynamic>>> listReminders(
    AssistantCredential credential,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> listNotes(
    AssistantCredential credential,
  ) async => [];

  @override
  Future<String> getDailySummary(AssistantCredential credential) async =>
      'No pending items for today.';
}

class FakeMicrophonePermissionService implements MicrophonePermissionService {
  MicrophonePermissionStatus status = MicrophonePermissionStatus.granted;

  @override
  Future<MicrophonePermissionStatus> checkPermission() async => status;

  @override
  Future<MicrophonePermissionStatus> requestPermission() async => status;

  @override
  Future<void> openAppSettings() async {}
}

class FakeOnDeviceSpeechRecognitionService
    implements OnDeviceSpeechRecognitionService {
  bool available = true;
  bool listening = false;
  bool handsFreeListening = false;
  int handsFreeStartCount = 0;
  int handsFreeResumeCount = 0;
  bool acceptNextCommand = false;
  String? recognitionProfile;
  Completer<void>? stopHandsFreeGate;
  Completer<void>? pauseHandsFreeGate;
  String transcript = 'assistant connection status';
  OnDeviceSpeechRecognitionException? startError;
  OnDeviceSpeechRecognitionException? stopError;

  final StreamController<HandsFreeSpeechEvent> handsFreeEventController =
      StreamController<HandsFreeSpeechEvent>.broadcast();

  @override
  Stream<HandsFreeSpeechEvent> get handsFreeEvents =>
      handsFreeEventController.stream;

  @override
  Future<OnDeviceSpeechAvailability> checkAvailability() async =>
      OnDeviceSpeechAvailability(
        available: available,
        platformVersion: 33,
        reason: available
            ? null
            : 'No installed on-device speech recognition service is available.',
      );

  @override
  Future<void> startListening({required String locale}) async {
    if (startError case final error?) throw error;
    listening = true;
  }

  @override
  Future<OnDeviceSpeechResult> stopListening() async {
    if (stopError case final error?) throw error;
    listening = false;
    return OnDeviceSpeechResult(transcript: transcript, confidence: 0.9);
  }

  @override
  Future<void> cancelListening() async {
    listening = false;
  }

  @override
  Future<void> startHandsFree({required String locale}) async {
    handsFreeStartCount += 1;
    handsFreeListening = true;
  }

  @override
  Future<void> pauseHandsFree() async {
    await pauseHandsFreeGate?.future;
  }

  @override
  Future<void> resumeHandsFree({bool acceptNextCommand = false}) async {
    handsFreeResumeCount += 1;
    this.acceptNextCommand = acceptNextCommand;
  }

  @override
  Future<void> stopHandsFree() async {
    final gate = stopHandsFreeGate;
    if (gate != null) {
      await gate.future;
      if (identical(stopHandsFreeGate, gate)) {
        stopHandsFreeGate = null;
      }
    }
    handsFreeListening = false;
  }

  @override
  Future<void> setRecognitionProfile(String profile) async {
    recognitionProfile = profile;
  }

  @override
  Future<void> dispose() async {
    listening = false;
    handsFreeListening = false;
    await handsFreeEventController.close();
  }
}

class FakeAssistanceController extends AssistanceController {
  FakeAssistanceController({
    MobileAssistanceState initialState = MobileAssistanceState.idle,
  }) : _initialState = AssistanceSessionState(state: initialState);

  final AssistanceSessionState _initialState;

  @override
  AssistanceSessionState build() => _initialState;

  void setAssistanceState(MobileAssistanceState newState) {
    state = AssistanceSessionState(state: newState);
  }

  @override
  Future<void> startAssistance() async {
    state = const AssistanceSessionState(state: MobileAssistanceState.active);
  }

  @override
  Future<void> stopAssistance() async {
    state = const AssistanceSessionState(state: MobileAssistanceState.idle);
  }

  @override
  Future<void> pauseAssistance() async {
    state = const AssistanceSessionState(state: MobileAssistanceState.paused);
  }
}

class FakeSpeechOutputService implements SpeechOutputService {
  @override
  bool isSpeaking = false;
  final List<String> spokenTexts = [];
  Completer<void>? speechGate;
  int stopCount = 0;

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    await speechGate?.future;
  }

  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    spokenTexts.add(text);
    onStart?.call();
    onDone?.call();
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> stop() async {
    stopCount++;
    isSpeaking = false;
  }

  @override
  Future<void> dispose() async {}
}

class FakeAudioRecorderService implements AudioRecorderService {
  @override
  bool isRecording = false;
  String? recordedPath;
  bool? speechActiveAtStart;
  FakeSpeechOutputService? speechOutput;

  @override
  Future<void> startRecording() async {
    speechActiveAtStart = speechOutput?.isSpeaking;
    isRecording = true;
  }

  @override
  Future<String?> stopRecording() async {
    isRecording = false;
    return recordedPath;
  }

  @override
  Future<void> cancelRecording() async => isRecording = false;

  @override
  Future<void> dispose() async => isRecording = false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAssistantCredentialRepository fakeCredRepo;
  late FakeAssistantRepository fakeAssistantRepo;
  late FakeMicrophonePermissionService fakePermService;
  late FakeOnDeviceSpeechRecognitionService fakeSpeechRecognizer;
  late FakeSpeechOutputService fakeSpeechOutput;
  late FakeAudioRecorderService fakeAudioRecorder;
  late FakeAssistanceController fakeAssistanceController;
  late ProviderContainer container;

  setUp(() {
    fakeCredRepo = FakeAssistantCredentialRepository();
    fakeAssistantRepo = FakeAssistantRepository();
    fakePermService = FakeMicrophonePermissionService();
    fakeSpeechRecognizer = FakeOnDeviceSpeechRecognitionService();
    fakeSpeechOutput = FakeSpeechOutputService();
    fakeAudioRecorder = FakeAudioRecorderService()
      ..speechOutput = fakeSpeechOutput;
    fakeAssistanceController = FakeAssistanceController();

    container = ProviderContainer(
      overrides: [
        geminiConfigurationRepositoryProvider.overrideWithValue(
          FakeGeminiConfigurationRepository(),
        ),
        assistantCredentialRepositoryProvider.overrideWithValue(fakeCredRepo),
        assistantRepositoryProvider.overrideWithValue(fakeAssistantRepo),
        microphonePermissionServiceProvider.overrideWithValue(fakePermService),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
          fakeSpeechRecognizer,
        ),
        speechOutputServiceProvider.overrideWithValue(fakeSpeechOutput),
        audioRecorderServiceProvider.overrideWithValue(fakeAudioRecorder),
        assistanceControllerProvider.overrideWith(
          () => fakeAssistanceController,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    appRouteObserver.currentRoute = null;
  });

  group('AssistantSessionController — Pairing', () {
    test('pair success persists credential and updates state', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      final error = await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );

      expect(error, isNull);
      final state = container.read(assistantSessionControllerProvider);
      expect(state.isPaired, isTrue);
      expect(state.credential?.displayName, equals('User'));
      expect(fakeCredRepo.credential, isNotNull);
    });

    test('pair failure returns error message', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      final error = await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'BADCODE',
      );

      expect(error, isNotNull);
      expect(error, contains('Invalid pairing code'));
      final state = container.read(assistantSessionControllerProvider);
      expect(state.isPaired, isFalse);
    });

    test('unpair removes credential and resets state', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
      expect(
        container.read(assistantSessionControllerProvider).isPaired,
        isTrue,
      );

      await controller.unpair();
      expect(
        container.read(assistantSessionControllerProvider).isPaired,
        isFalse,
      );
      expect(fakeCredRepo.credential, isNull);
    });
  });

  group('AssistantSessionController — Backend connection', () {
    test(
      'loads saved pairing once and shares concurrent connection checks',
      () async {
        final load = Completer<AssistantCredential?>();
        final health = Completer<int?>();
        fakeCredRepo.loadGate = load;
        fakeAssistantRepo.healthGate = health;
        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );
        final first = controller.connectBackend();
        final second = controller.connectBackend();
        expect(identical(first, second), isTrue);
        expect(fakeAssistantRepo.healthCheckCount, 0);
        load.complete(
          AssistantCredential(
            backendUrl: 'http://macbook.local:8765',
            bearerToken: 'fake_token',
            userId: 'test_user',
            displayName: 'User',
            pairedAt: DateTime(2026),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(fakeCredRepo.loadCount, 1);
        expect(fakeAssistantRepo.healthCheckCount, 1);
        expect(
          container.read(assistantSessionControllerProvider).backendStatus,
          AssistantBackendStatus.checking,
        );
        expect(
          container.read(assistantSessionControllerProvider).sessionState,
          AssistantSessionState.idle,
        );
        health.complete(1);
        await first;
        expect(
          container.read(assistantSessionControllerProvider).backendStatus,
          AssistantBackendStatus.reachable,
        );
        expect(fakeAssistantRepo.textQueryCount, 0);
      },
    );

    test('unpaired entry does not contact or silently pair a laptop', () async {
      await container
          .read(assistantSessionControllerProvider.notifier)
          .connectBackend();
      expect(fakeAssistantRepo.healthCheckCount, 0);
      expect(
        container.read(assistantSessionControllerProvider).isPaired,
        isFalse,
      );
    });

    test('late health result cannot restore a revoked pairing', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );
      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
      final health = Completer<int?>();
      fakeAssistantRepo.healthGate = health;
      final connecting = controller.connectBackend();
      await Future<void>.delayed(Duration.zero);
      await controller.unpair();
      health.complete(1);
      await connecting;
      final state = container.read(assistantSessionControllerProvider);
      expect(state.isPaired, isFalse);
      expect(state.backendStatus, AssistantBackendStatus.notChecked);
    });

    test('version mismatch is reported and a retry can recover', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );
      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
      fakeAssistantRepo.serverVersion = 2;
      await controller.connectBackend();
      expect(
        container.read(assistantSessionControllerProvider).backendStatus,
        AssistantBackendStatus.incompatible,
      );
      fakeAssistantRepo.serverVersion = 1;
      await controller.connectBackend();
      expect(
        container.read(assistantSessionControllerProvider).backendStatus,
        AssistantBackendStatus.reachable,
      );
      expect(fakeAssistantRepo.healthCheckCount, 2);
      expect(fakeAssistantRepo.textQueryCount, 0);
    });

    test(
      'offline app controls run while backend connection is pending',
      () async {
        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );
        await controller.pair(
          backendUrl: 'http://macbook.local:8765',
          pairingCode: 'GOODCODE',
        );
        final health = Completer<int?>();
        fakeAssistantRepo.healthGate = health;
        final connecting = controller.connectBackend();
        await controller.sendTextQuery('assistant connection status');
        expect(
          container.read(assistantSessionControllerProvider).sessionState,
          AssistantSessionState.completed,
        );
        health.complete(null);
        await connecting;
        expect(
          container.read(assistantSessionControllerProvider).sessionState,
          AssistantSessionState.completed,
        );
        expect(
          container.read(assistantSessionControllerProvider).backendStatus,
          AssistantBackendStatus.unavailable,
        );
      },
    );
  });

  group('AssistantSessionController — Offline App Controls', () {
    test('changes sensitivity while completely unpaired', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('reduce sensitivity');

      var state = container.read(assistantSessionControllerProvider);
      expect(state.isPaired, isFalse);
      expect(state.sessionState, AssistantSessionState.completed);

      expect(
        container
            .read(appSettingsControllerProvider)
            .detectionSettings
            .sensitivity,
        DetectionSensitivity.low,
      );
      expect(state.conversationHistory.last.text, contains('low'));
    });

    test('reads assistant status while unpaired without a backend', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('assistant connection status');

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.completed);
      expect(state.isPaired, isFalse);
      expect(state.conversationHistory.last.text, contains('not paired'));
      expect(state.conversationHistory.last.text, contains('not paired'));
    });

    test('general conversation still asks for the optional backend', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Tell me a short story');

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.laptopUnavailable);
      expect(state.errorMessage, 'No assistant backend is paired.');
    });
  });

  group('VisionVoiceKernelV3 — persistent foreground session', () {
    Future<void> settleVoice() =>
        Future<void>.delayed(const Duration(milliseconds: 25));

    test(
      'stopped wearable speech cannot resume recognition a second time',
      () async {
        final kernel = container.read(visionVoiceKernelProvider.notifier);
        await settleVoice();
        final gate = Completer<void>();
        fakeSpeechOutput.speechGate = gate;
        final speaking = kernel.speakFeedback('Car ahead', reportFailure: true);
        await settleVoice();
        await kernel.stopSpeaking();
        final resumeCount = fakeSpeechRecognizer.handsFreeResumeCount;
        gate.complete();
        await speaking;
        expect(fakeSpeechRecognizer.handsFreeResumeCount, resumeCount);
      },
    );

    test(
      'stopping during microphone pause prevents delayed wearable speech',
      () async {
        final kernel = container.read(visionVoiceKernelProvider.notifier);
        await settleVoice();
        final gate = Completer<void>();
        fakeSpeechRecognizer.pauseHandsFreeGate = gate;
        final speaking = kernel.speakFeedback('Chair on the left');
        await settleVoice();
        await kernel.stopSpeaking();
        gate.complete();
        await speaking;
        expect(
          fakeSpeechOutput.spokenTexts,
          isNot(contains('Chair on the left')),
        );
      },
    );

    test(
      'one wake keeps accepting commands and timeout does not sleep',
      () async {
        container.read(visionVoiceKernelProvider);
        await settleVoice();

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.wake),
        );
        await settleVoice();

        expect(
          container.read(visionVoiceKernelProvider).isCommandSessionActive,
          isTrue,
        );
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(
            type: HandsFreeSpeechEventType.command,
            transcript: 'what time is it',
          ),
        );
        await settleVoice();

        expect(
          container.read(visionVoiceKernelProvider).isCommandSessionActive,
          isTrue,
        );
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.timeout),
        );
        await settleVoice();

        expect(
          container.read(visionVoiceKernelProvider).isCommandSessionActive,
          isTrue,
        );
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);
      },
    );

    test(
      'bye homophones do not end an active offline command session',
      () async {
        container.read(visionVoiceKernelProvider);
        await settleVoice();
        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.wake),
        );
        await settleVoice();
        for (final phrase in [
          'buy',
          'by',
          'bye',
          'a book by an author',
          'do not stop listening',
        ]) {
          fakeSpeechRecognizer.handsFreeEventController.add(
            HandsFreeSpeechEvent(
              type: HandsFreeSpeechEventType.command,
              transcript: phrase,
            ),
          );
          await settleVoice();
          expect(
            container.read(visionVoiceKernelProvider).isCommandSessionActive,
            isTrue,
            reason: phrase,
          );
          expect(
            fakeSpeechRecognizer.acceptNextCommand,
            isTrue,
            reason: phrase,
          );
        }
      },
    );

    test('scanner commands remain active until goodbye', () async {
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      await settleVoice();
      fakeSpeechRecognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.wake),
      );
      await settleVoice();

      kernel.setFeatureContext(VoiceFeatureContext.scannerReading);
      await settleVoice();
      expect(fakeSpeechRecognizer.recognitionProfile, 'scanner_commands');

      fakeSpeechRecognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'make the reading faster',
        ),
      );
      await settleVoice();

      var voiceState = container.read(visionVoiceKernelProvider);
      expect(voiceState.lastResolvedCommand?.intent, isA<SetReadingProfile>());
      expect(voiceState.isCommandSessionActive, isTrue);
      expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);

      fakeSpeechRecognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'repeat this sentence',
        ),
      );
      await settleVoice();

      voiceState = container.read(visionVoiceKernelProvider);
      expect(voiceState.lastResolvedCommand?.intent, isA<ReadingRepeat>());
      expect(voiceState.isCommandSessionActive, isTrue);

      fakeSpeechRecognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'goodbye',
        ),
      );
      await settleVoice();

      voiceState = container.read(visionVoiceKernelProvider);
      expect(voiceState.isCommandSessionActive, isFalse);
      expect(fakeSpeechRecognizer.acceptNextCommand, isFalse);
    });

    test(
      'explicit exit leaves Smart AI but preserves the offline command session',
      () async {
        final kernel = container.read(visionVoiceKernelProvider.notifier);
        await settleVoice();
        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.wake),
        );
        await settleVoice();
        kernel.setFeatureContext(VoiceFeatureContext.smartAi);

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(
            type: HandsFreeSpeechEventType.command,
            transcript: 'exit smart ai',
          ),
        );
        await settleVoice();

        final voiceState = container.read(visionVoiceKernelProvider);
        expect(voiceState.activeContext, VoiceFeatureContext.unknown);
        expect(voiceState.isCommandSessionActive, isTrue);
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);
      },
    );
  });

  group('AssistantSessionController — Text Query', () {
    setUp(() async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );
      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
    });

    test('sendTextQuery updates conversation history and completes', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Tell me a joke about dogs.');

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, equals(AssistantSessionState.completed));
      expect(state.conversationHistory.length, equals(2)); // User + Assistant
      expect(
        state.conversationHistory.first.text,
        equals('Tell me a joke about dogs.'),
      );
      expect(state.conversationHistory.last.text, contains('Echo'));
    });

    test(
      'wake-driven Smart AI conversation uses the backend text path',
      () async {
        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );

        await controller.sendConversationQuery(
          'How do guide dogs learn routes?',
        );

        final state = container.read(assistantSessionControllerProvider);
        expect(state.sessionState, AssistantSessionState.completed);
        expect(state.conversationHistory.first.text, contains('guide dogs'));
        expect(state.conversationHistory.last.text, contains('Echo'));
        expect(fakeAssistantRepo.textQueryCount, 1);
        expect(
          fakeSpeechRecognizer.handsFreeStartCount,
          greaterThanOrEqualTo(1),
        );
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);
      },
    );

    test(
      'Smart AI hands-free event routes unmatched speech to backend',
      () async {
        final kernel = container.read(visionVoiceKernelProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        kernel.setFeatureContext(VoiceFeatureContext.smartAi);

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(
            type: HandsFreeSpeechEventType.command,
            transcript: 'Explain how guide dogs learn routes',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fakeAssistantRepo.textQueryCount, 1);
        expect(
          container
              .read(assistantSessionControllerProvider)
              .conversationHistory
              .last
              .text,
          contains('Echo'),
        );
        expect(fakeSpeechRecognizer.acceptNextCommand, isTrue);
      },
    );

    test(
      'Smart AI hands-free ignores low-information noise transcript',
      () async {
        final kernel = container.read(visionVoiceKernelProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        kernel.setFeatureContext(VoiceFeatureContext.smartAi);

        fakeSpeechRecognizer.handsFreeEventController.add(
          const HandsFreeSpeechEvent(
            type: HandsFreeSpeechEventType.command,
            transcript: 'the the',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fakeAssistantRepo.textQueryCount, 0);
        expect(
          container
              .read(assistantSessionControllerProvider)
              .conversationHistory,
          isEmpty,
        );
      },
    );

    test('sendTextQuery fails gracefully when laptop is unreachable', () async {
      fakeAssistantRepo.isReachable = false;
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Tell me a short story.');

      final state = container.read(assistantSessionControllerProvider);
      expect(
        state.sessionState,
        equals(AssistantSessionState.laptopUnavailable),
      );
    });

    test('confirmed backend command updates state and completes', () async {
      fakeAssistantRepo.nextTextResponse = const AssistantResponse(
        responseText: 'I can set a reminder.',
        requestId: 'req_reminder',
        toolCall: AssistantToolCall(
          name: 'set_reminder',
          arguments: {'time': 'tomorrow'},
        ),
        requiresConfirmation: true,
      );
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Set a reminder');
      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.awaitingConfirmation,
      );

      await controller.confirmAction();

      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.completed,
      );
    });
  });

  group('AssistantSessionController — Push-to-Talk Lifecycle', () {
    Future<AssistantSessionController> prepareSmartAi() async {
      appRouteObserver.currentRoute = RoutePaths.assistant;
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );
      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
      return controller;
    }

    test(
      'Smart AI stops shared speaker output before microphone capture',
      () async {
        final controller = await prepareSmartAi();
        fakeSpeechOutput.isSpeaking = true;
        final priorStops = fakeSpeechOutput.stopCount;
        await controller.startListening();
        expect(fakeSpeechOutput.stopCount, greaterThan(priorStops));
        expect(fakeAudioRecorder.speechActiveAtStart, isFalse);
        expect(fakeAudioRecorder.isRecording, isTrue);
      },
    );

    for (final reachable in [true, false]) {
      test(
        'Smart AI deletes temporary clip after upload (reachable: $reachable)',
        () async {
          final controller = await prepareSmartAi();
          final directory = await Directory.systemTemp.createTemp(
            'synthetic_speech_test_',
          );
          addTearDown(() => directory.delete(recursive: true));
          final clip = File('${directory.path}/synthetic.m4a');
          await clip.writeAsBytes(List.filled(512, 0));
          fakeAudioRecorder.recordedPath = clip.path;
          fakeAssistantRepo.isReachable = reachable;
          await controller.startListening();
          await controller.stopListeningAndSubmit();
          expect(await clip.exists(), isFalse);
          expect(fakeAudioRecorder.isRecording, isFalse);
          expect(
            container.read(assistantSessionControllerProvider).sessionState,
            reachable
                ? AssistantSessionState.completed
                : AssistantSessionState.laptopUnavailable,
          );
        },
      );
    }

    test('backgrounding Smart AI cancels its microphone recording', () async {
      final controller = await prepareSmartAi();
      await controller.startListening();
      expect(fakeAudioRecorder.isRecording, isTrue);
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(fakeAudioRecorder.isRecording, isFalse);
      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.cancelled,
      );
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    for (final statusCode in [422, 413]) {
      test(
        'audio HTTP $statusCode offers speech recovery and deletes clip',
        () async {
          final controller = await prepareSmartAi();
          final directory = await Directory.systemTemp.createTemp(
            'synthetic_speech_test_',
          );
          addTearDown(() => directory.delete(recursive: true));
          final clip = File('${directory.path}/synthetic.m4a');
          await clip.writeAsBytes(List.filled(512, 0));
          fakeAudioRecorder.recordedPath = clip.path;
          fakeAssistantRepo.audioFailure = AssistantNetworkException(
            'Synthetic audio rejection',
            statusCode: statusCode,
          );
          await controller.startListening();
          await controller.stopListeningAndSubmit();
          final state = container.read(assistantSessionControllerProvider);
          expect(state.sessionState, AssistantSessionState.error);
          expect(
            state.failureKind,
            statusCode == 422
                ? AssistantFailureKind.transcriptionFailed
                : AssistantFailureKind.audioTooLarge,
          );
          expect(state.conversationHistory, isEmpty);
          expect(await clip.exists(), isFalse);
          if (statusCode == 422) {
            expect(state.errorMessage, contains('repeat your full question'));
          }
        },
      );
    }

    test('starts phone-local listening while completely unpaired', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.startListening();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, equals(AssistantSessionState.listening));
      expect(state.isPaired, isFalse);
      expect(fakeSpeechRecognizer.listening, isTrue);
    });

    test(
      'cancelListening cancels on-device recognition and transitions',
      () async {
        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );

        await controller.startListening();
        await controller.cancelListening();

        final state = container.read(assistantSessionControllerProvider);
        expect(state.sessionState, equals(AssistantSessionState.cancelled));
        expect(fakeSpeechRecognizer.listening, isFalse);
      },
    );

    test('permission denied prevents recognition', () async {
      fakePermService.status = MicrophonePermissionStatus.denied;
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.startListening();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, equals(AssistantSessionState.error));
      expect(
        state.failureKind,
        equals(AssistantFailureKind.microphonePermissionDenied),
      );
      expect(fakeSpeechRecognizer.listening, isFalse);
    });

    test('unavailable on-device service never falls back to backend', () async {
      fakeSpeechRecognizer.available = false;
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.startListening();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.error);
      expect(state.failureKind, AssistantFailureKind.onDeviceSpeechUnavailable);
      expect(fakeAssistantRepo.textQueryCount, 0);
    });

    test('recognized app-control speech executes without backend', () async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.startListening();
      await controller.stopListeningAndSubmit();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.completed);
      expect(state.lastTranscript, 'assistant connection status');
      expect(state.conversationHistory.last.text, contains('not paired'));
      expect(fakeAssistantRepo.textQueryCount, 0);
    });

    test('spoken sensitivity control executes synchronously', () async {
      fakeSpeechRecognizer.transcript = 'reduce sensitivity';
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.startListening();
      await controller.stopListeningAndSubmit();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.completed);

      expect(
        container
            .read(appSettingsControllerProvider)
            .detectionSettings
            .sensitivity,
        DetectionSensitivity.low,
      );
      expect(state.conversationHistory.last.text, contains('low'));
      expect(fakeAssistantRepo.textQueryCount, 0);
    });
  });

  group('AssistantSessionController — Action Confirmation', () {
    setUp(() async {
      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );
      await controller.pair(
        backendUrl: 'http://macbook.local:8765',
        pairingCode: 'GOODCODE',
      );
    });

    for (final confirm in [true, false]) {
      test(
        'server deletion reports explicit ${confirm ? 'confirmation' : 'cancellation'} once',
        () async {
          fakeAssistantRepo.nextTextResponse = const AssistantResponse(
            responseText: 'Delete the saved note?',
            requestId: 'server-delete',
            toolCall: AssistantToolCall(
              name: 'delete_note',
              arguments: {'note_id': 'test-note'},
            ),
            requiresConfirmation: true,
          );
          final controller = container.read(
            assistantSessionControllerProvider.notifier,
          );
          await controller.sendTextQuery('Remove a saved note');
          expect(fakeAssistantRepo.reportedResults, isEmpty);
          if (confirm) {
            await controller.confirmAction();
            await controller.confirmAction();
          } else {
            await controller.cancelAction();
            await controller.confirmAction();
          }
          expect(fakeAssistantRepo.reportedResults, hasLength(1));
          expect(
            fakeAssistantRepo.reportedResults.single.toolName,
            'delete_note',
          );
          expect(fakeAssistantRepo.reportedResults.single.success, confirm);
        },
      );
    }

    test(
      'lost server confirmation never claims the deletion completed',
      () async {
        fakeAssistantRepo.failToolReport = true;
        fakeAssistantRepo.nextTextResponse = const AssistantResponse(
          responseText: 'Delete the saved note?',
          requestId: 'server-delete',
          toolCall: AssistantToolCall(
            name: 'delete_note',
            arguments: {'note_id': 'test-note'},
          ),
          requiresConfirmation: true,
        );
        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );
        await controller.sendTextQuery('Remove a saved note');
        await controller.confirmAction();
        expect(
          container
              .read(assistantSessionControllerProvider)
              .pendingResponse!
              .responseText,
          contains('did not confirm the action'),
        );
      },
    );

    test('confirmation flow completes when confirmed', () async {
      fakeAssistantRepo.nextTextResponse = const AssistantResponse(
        responseText: 'I will set a reminder.',
        requestId: 'req_rem_1',
        toolCall: AssistantToolCall(name: 'get_current_time', arguments: {}),
        requiresConfirmation: true,
        confirmationPrompt: 'Set reminder for tomorrow at 8pm?',
      );

      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Remind me tomorrow');

      var state = container.read(assistantSessionControllerProvider);
      expect(
        state.sessionState,
        equals(AssistantSessionState.awaitingConfirmation),
      );
      expect(
        state.pendingResponse?.confirmationPrompt,
        contains('Set reminder'),
      );

      // Confirm
      await controller.confirmAction();

      state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, equals(AssistantSessionState.completed));
    });

    test('confirmation flow cancels when user cancels', () async {
      fakeAssistantRepo.nextTextResponse = const AssistantResponse(
        responseText: 'I will set a reminder.',
        requestId: 'req_rem_2',
        toolCall: AssistantToolCall(name: 'get_current_time', arguments: {}),
        requiresConfirmation: true,
      );

      final controller = container.read(
        assistantSessionControllerProvider.notifier,
      );

      await controller.sendTextQuery('Remind me tomorrow');
      await controller.cancelAction();

      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, equals(AssistantSessionState.cancelled));
    });
  });
}
