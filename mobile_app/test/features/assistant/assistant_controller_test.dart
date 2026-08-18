import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_blind_assistant/app/assistance_controller.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/assistant_session_controller.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_response.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_tool_result.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_failure_kind.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_session_state.dart';
import 'package:ai_blind_assistant/domain/enums/detection_sensitivity.dart';
import 'package:ai_blind_assistant/domain/enums/microphone_permission_status.dart';
import 'package:ai_blind_assistant/domain/enums/mobile_assistance_state.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_credential_repository.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_repository.dart';
import 'package:ai_blind_assistant/domain/services/microphone_permission_service.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class FakeAssistantCredentialRepository
    implements AssistantCredentialRepository {
  AssistantCredential? credential;

  @override
  Future<AssistantCredential?> loadCredential() async => credential;

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

  @override
  Future<int?> checkHealth(AssistantCredential credential) async {
    return isReachable ? serverVersion : null;
  }

  @override
  Future<AssistantCredential> pair({
    required String backendUrl,
    required String pairingCode,
  }) async {
    textQueryCount += 1;
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
  Completer<void>? stopHandsFreeGate;
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
  Future<void> pauseHandsFree() async {}

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
  Future<void> setRecognitionProfile(String profile) async {}

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

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
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
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
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
  late FakeAssistanceController fakeAssistanceController;
  late ProviderContainer container;

  setUp(() {
    fakeCredRepo = FakeAssistantCredentialRepository();
    fakeAssistantRepo = FakeAssistantRepository();
    fakePermService = FakeMicrophonePermissionService();
    fakeSpeechRecognizer = FakeOnDeviceSpeechRecognitionService();
    fakeSpeechOutput = FakeSpeechOutputService();
    fakeAssistanceController = FakeAssistanceController();

    container = ProviderContainer(
      overrides: [
        assistantCredentialRepositoryProvider.overrideWithValue(fakeCredRepo),
        assistantRepositoryProvider.overrideWithValue(fakeAssistantRepo),
        microphonePermissionServiceProvider.overrideWithValue(fakePermService),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
          fakeSpeechRecognizer,
        ),
        speechOutputServiceProvider.overrideWithValue(fakeSpeechOutput),
        assistanceControllerProvider.overrideWith(
          () => fakeAssistanceController,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
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
      expect(
        state.conversationHistory.last.text,
        contains('not paired'),
      );
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
      expect(
        state.sessionState,
        AssistantSessionState.completed,
      );

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
