import 'dart:async';

import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/assistant_session_controller.dart';
import 'package:ai_blind_assistant/app/router/app_route_observer.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_session_state.dart';
import 'package:ai_blind_assistant/domain/services/gemini_conversation_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_controller_test.dart';
import '../../helpers/gemini_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGeminiConfigurationRepository config;
  late FakeGeminiConversationService gemini;
  late FakeAssistantRepository laptop;
  late FakeAssistantCredentialRepository pairing;
  late FakeSpeechOutputService speech;
  late FakeOnDeviceSpeechRecognitionService recognizer;
  late FakeAudioRecorderService recorder;
  late ProviderContainer container;
  late AssistantSessionController controller;

  setUp(() async {
    config = FakeGeminiConfigurationRepository();
    gemini = FakeGeminiConversationService();
    laptop = FakeAssistantRepository()..isReachable = false;
    pairing = FakeAssistantCredentialRepository();
    speech = FakeSpeechOutputService();
    recognizer = FakeOnDeviceSpeechRecognitionService();
    recorder = FakeAudioRecorderService();
    container = ProviderContainer(
      overrides: [
        geminiConfigurationRepositoryProvider.overrideWithValue(config),
        geminiConversationServiceProvider.overrideWithValue(gemini),
        assistantCredentialRepositoryProvider.overrideWithValue(pairing),
        assistantRepositoryProvider.overrideWithValue(laptop),
        speechOutputServiceProvider.overrideWithValue(speech),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(recognizer),
        audioRecorderServiceProvider.overrideWithValue(recorder),
        microphonePermissionServiceProvider.overrideWithValue(
          FakeMicrophonePermissionService(),
        ),
      ],
    );
    controller = container.read(assistantSessionControllerProvider.notifier);
    await controller.loadGeminiConfiguration();
    await controller.loadStoredCredential();
    appRouteObserver.currentRoute = RoutePaths.assistant;
  });
  tearDown(() {
    container.dispose();
    appRouteObserver.currentRoute = null;
  });

  test(
    'conversation works without laptop pairing or health checks and speaks on phone',
    () async {
      expect(
        await controller.enableDirectGemini(testGeminiConfiguration),
        isNull,
      );
      await controller.connectBackend();
      expect(gemini.queries, isEmpty);
      await controller.sendConversationQuery('Explain the solar system');
      expect(gemini.queries, ['Explain the solar system']);
      expect(laptop.healthCheckCount, 0);
      expect(laptop.textQueryCount, 0);
      expect(speech.spokenTexts, contains(gemini.response));
      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.completed,
      );
    },
  );

  test(
    'typed local controls bypass Gemini even with laptop unavailable',
    () async {
      await controller.enableDirectGemini(testGeminiConfiguration);
      await controller.sendTextQuery('assistant connection status');
      expect(gemini.queries, isEmpty);
      expect(laptop.textQueryCount, 0);
      expect(
        container
            .read(assistantSessionControllerProvider)
            .conversationHistory
            .last
            .text,
        contains('Gemini directly'),
      );
      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.completed,
      );
    },
  );

  test('Speak uses phone recognizer even when laptop is paired', () async {
    await controller.pair(
      backendUrl: 'http://192.168.43.2:8765',
      pairingCode: 'TEST',
    );
    await controller.enableDirectGemini(testGeminiConfiguration);
    recognizer.transcript = 'Explain the solar system';
    await controller.startListening();
    expect(recorder.isRecording, isFalse);
    expect(recognizer.listening, isTrue);
    await controller.stopListeningAndSubmit();
    expect(gemini.queries, ['Explain the solar system']);
    expect(laptop.healthCheckCount, 0);
    expect(gemini.lastHistory, isEmpty);
    expect(
      container
          .read(assistantSessionControllerProvider)
          .conversationHistory
          .where((message) => message.isUser)
          .length,
      1,
    );
  });

  test(
    'quota failure gives Gemini recovery without saying laptop unavailable',
    () async {
      await controller.enableDirectGemini(testGeminiConfiguration);
      gemini.failure = const GeminiConversationException(
        'Gemini quota reached.',
      );
      await controller.sendConversationQuery('Explain the solar system');
      final state = container.read(assistantSessionControllerProvider);
      expect(state.sessionState, AssistantSessionState.error);
      expect(state.errorMessage, 'Gemini quota reached.');
    },
  );

  test(
    'provider output that resembles a tool remains plain conversation',
    () async {
      await controller.enableDirectGemini(testGeminiConfiguration);
      gemini.response = '{"tool_call":{"name":"stop_everything"}}';
      await controller.sendConversationQuery('Explain app actions');
      final response = container
          .read(assistantSessionControllerProvider)
          .pendingResponse!;
      expect(response.hasToolCall, isFalse);
      expect(laptop.reportedResults, isEmpty);
    },
  );

  test(
    'removing the key clears cloud history and preserves laptop pairing',
    () async {
      await controller.pair(
        backendUrl: 'http://192.168.43.2:8765',
        pairingCode: 'TEST',
      );
      await controller.enableDirectGemini(testGeminiConfiguration);
      await controller.sendConversationQuery('Explain the solar system');
      expect(await controller.disableDirectGemini(), isNull);
      final state = container.read(assistantSessionControllerProvider);
      expect(state.usesDirectGemini, isFalse);
      expect(state.isPaired, isTrue);
      expect(state.conversationHistory, isEmpty);
      expect(config.configuration, isNull);
    },
  );

  test('save/delete failure keeps the real provider selection', () async {
    config.failSave = true;
    expect(
      await controller.enableDirectGemini(testGeminiConfiguration),
      isNotNull,
    );
    expect(
      container.read(assistantSessionControllerProvider).usesDirectGemini,
      isFalse,
    );
    config.failSave = false;
    await controller.enableDirectGemini(testGeminiConfiguration);
    config.failDelete = true;
    expect(await controller.disableDirectGemini(), isNotNull);
    expect(
      container.read(assistantSessionControllerProvider).usesDirectGemini,
      isTrue,
    );
  });

  test('laptop history is not loaded or cleared while using Gemini', () async {
    await controller.pair(
      backendUrl: 'http://192.168.43.2:8765',
      pairingCode: 'TEST',
    );
    laptop.history = [
      AssistantMessage(
        id: 'private',
        role: AssistantMessageRole.user,
        text: 'Synthetic laptop-only text',
        createdAt: DateTime(2026),
      ),
    ];
    await controller.enableDirectGemini(testGeminiConfiguration);
    await controller.loadHistory();
    expect(
      container.read(assistantSessionControllerProvider).conversationHistory,
      isEmpty,
    );
    await controller.clearHistory();
    expect(laptop.history, hasLength(1));
  });

  test(
    'background invalidates a late cloud answer and cancels its request',
    () async {
      await controller.enableDirectGemini(testGeminiConfiguration);
      gemini.gate = Completer<String>();
      final query = controller.sendConversationQuery(
        'Explain the solar system',
      );
      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      gemini.gate!.complete('Late answer');
      await query;
      expect(gemini.cancellations, greaterThan(0));
      expect(speech.spokenTexts, isNot(contains('Late answer')));
      expect(
        container.read(assistantSessionControllerProvider).sessionState,
        AssistantSessionState.cancelled,
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    },
  );
}
