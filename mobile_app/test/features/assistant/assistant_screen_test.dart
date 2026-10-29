import '../../helpers/gemini_fakes.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/features/assistant/presentation/smart_ai_cloud_connection_card.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/features/assistant/presentation/assistant_screen.dart';

import 'assistant_controller_test.dart';

void main() {
  late FakeAssistantCredentialRepository fakeCredRepo;
  late FakeAssistantRepository fakeAssistantRepo;
  late FakeMicrophonePermissionService fakePermService;
  late FakeOnDeviceSpeechRecognitionService fakeSpeechRecognizer;

  setUp(() {
    fakeCredRepo = FakeAssistantCredentialRepository();
    fakeAssistantRepo = FakeAssistantRepository();
    fakePermService = FakeMicrophonePermissionService();
    fakeSpeechRecognizer = FakeOnDeviceSpeechRecognitionService();
  });

  Widget buildTestableScreen({
    AssistantCredential? initialCredential,
    String? initialDraft,
    bool cloudEnabled = false,
    bool geminiEnabled = false,
  }) {
    if (initialCredential != null) {
      fakeCredRepo.credential = initialCredential;
    }
    return ProviderScope(
      overrides: [
        smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
          FakeSmartAiConfigurationRepository()
            ..configuration = cloudEnabled ? testSmartAiConfiguration : null,
        ),
        smartAiAudioCoordinatorProvider.overrideWithValue(
          FakeSmartAiAudioCoordinator([]),
        ),
        smartAiCloudServiceProvider.overrideWithValue(FakeSmartAiService([])),
        geminiConfigurationRepositoryProvider.overrideWithValue(
          FakeGeminiConfigurationRepository()
            ..configuration = geminiEnabled ? testGeminiConfiguration : null,
        ),
        assistantCredentialRepositoryProvider.overrideWithValue(fakeCredRepo),
        assistantRepositoryProvider.overrideWithValue(fakeAssistantRepo),
        microphonePermissionServiceProvider.overrideWithValue(fakePermService),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
          fakeSpeechRecognizer,
        ),
      ],
      child: MaterialApp(
        home: AssistantScreen(initialDraft: initialDraft),
        routes: {
          RoutePaths.assistantConnection: (_) => Scaffold(
            appBar: AppBar(title: const Text('Connect Assistant')),
            body: const SingleChildScrollView(
              child: SmartAiCloudConnectionCard(),
            ),
          ),
        },
      ),
    );
  }

  Future<void> openOtherAssistant(WidgetTester tester) async {
    final other = find.byKey(const Key('smart_ai_other_assistants'));
    if (other.evaluate().isEmpty) return;
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
  }

  group('AssistantScreen UI & Accessibility', () {
    testWidgets(
      'fresh phone keeps the circle and exposes setup without provider requests',
      (tester) async {
        await tester.pumpWidget(buildTestableScreen());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('smart_ai_voice_circle')), findsOneWidget);
        expect(find.text('Set up Smart AI on this phone'), findsOneWidget);
        expect(find.byKey(const Key('smart_ai_setup')), findsOneWidget);
        expect(find.byKey(AppKeys.assistantPushToTalkButton), findsNothing);
        expect(find.textContaining('cloud audio is enabled'), findsNothing);
        expect(fakeAssistantRepo.healthCheckCount, 0);
        expect(fakeAssistantRepo.textQueryCount, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'saved personal Gemini keeps its selected mode without laptop checks',
      (tester) async {
        await tester.pumpWidget(buildTestableScreen(geminiEnabled: true));
        await tester.pumpAndSettle();
        expect(find.byKey(AppKeys.assistantPushToTalkButton), findsOneWidget);
        expect(find.byKey(const Key('smart_ai_voice_circle')), findsNothing);
        expect(fakeAssistantRepo.healthCheckCount, 0);
        expect(fakeAssistantRepo.textQueryCount, 0);
      },
    );

    testWidgets(
      'setup and key removal keep the circle without submitting a draft',
      (tester) async {
        await tester.pumpWidget(
          buildTestableScreen(initialDraft: 'Unsent private draft.'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('smart_ai_setup')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Set up personal Smart AI keys'));
        await tester.tap(find.text('Set up personal Smart AI keys'));
        await tester.pumpAndSettle();
        final key = find.byKey(const Key('smart_ai_groq_key'));
        await tester.ensureVisible(key);
        await tester.enterText(key, testGroqSmartAiConfiguration.groqKey);
        final consent = find.byKey(const Key('smart_ai_cloud_consent'));
        await tester.ensureVisible(consent);
        await tester.tap(consent);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Use Groq for Smart AI');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('smart_ai_voice_circle')), findsOneWidget);
        expect(find.text('Ready for your question'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('smart_ai_question')))
              .controller!
              .text,
          'Unsent private draft.',
        );
        expect(fakeAssistantRepo.healthCheckCount, 0);
        expect(fakeAssistantRepo.textQueryCount, 0);
        await tester.tap(find.byTooltip('Smart AI cloud connection settings'));
        await tester.pumpAndSettle();
        final remove = find.text('Remove Smart AI cloud keys');
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('smart_ai_voice_circle')), findsOneWidget);
        expect(find.text('Set up Smart AI on this phone'), findsOneWidget);
        expect(find.byKey(AppKeys.assistantPushToTalkButton), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('smart_ai_question')))
              .controller!
              .text,
          'Unsent private draft.',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'configured Smart AI opens its isolated cloud view without laptop checks',
      (tester) async {
        await tester.pumpWidget(buildTestableScreen(cloudEnabled: true));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('smart_ai_voice_circle')), findsOneWidget);
        expect(fakeAssistantRepo.healthCheckCount, 0);
        expect(fakeAssistantRepo.textQueryCount, 0);
        expect(fakeSpeechRecognizer.listening, false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'paired speech discloses laptop-only audio and deletion before Speak',
      (tester) async {
        await tester.pumpWidget(
          buildTestableScreen(
            initialCredential: AssistantCredential(
              backendUrl: 'http://macbook.local:8765',
              bearerToken: 'fake_token',
              userId: 'test_user',
              displayName: 'User',
              pairedAt: DateTime(2026),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final disclosure = find.text(
          'For clearer questions, use Speak. A temporary recording goes '
          'only to your paired laptop for speech recognition, then is '
          'deleted from both devices. Hands-free speech stays on this phone.',
        );
        expect(disclosure, findsOneWidget);
        expect(
          tester.getTopLeft(disclosure).dy,
          lessThan(
            tester.getTopLeft(find.byKey(AppKeys.assistantPushToTalkButton)).dy,
          ),
        );
        expect(
          find.textContaining('audio are never sent to Gemini'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Camera frames and raw audio are never sent.'),
          findsNothing,
        );
        expect(fakeSpeechRecognizer.listening, isFalse);
        expect(fakeAssistantRepo.textQueryCount, 0);
      },
    );

    testWidgets(
      'checks saved laptop on entry without submitting the OCR draft',
      (tester) async {
        final gate = Completer<int?>();
        fakeAssistantRepo.healthGate = gate;
        await tester.pumpWidget(
          buildTestableScreen(
            initialCredential: AssistantCredential(
              backendUrl: 'http://macbook.local:8765',
              bearerToken: 'fake_token',
              userId: 'test_user',
              displayName: 'User',
              pairedAt: DateTime(2026),
            ),
            initialDraft: 'Unsent OCR draft.',
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(fakeAssistantRepo.healthCheckCount, 1);
        expect(find.text('Connecting to laptop assistant'), findsOneWidget);
        expect(fakeAssistantRepo.textQueryCount, 0);
        gate.complete(1);
        await tester.pumpAndSettle();
        expect(find.text('Laptop assistant is reachable'), findsOneWidget);
        expect(fakeAssistantRepo.textQueryCount, 0);
        expect(
          tester
              .widget<TextField>(find.byKey(AppKeys.assistantTextInput))
              .controller
              ?.text,
          'Unsent OCR draft.',
        );
      },
    );

    testWidgets(
      'connection timeout offers a check-only retry without resending text',
      (tester) async {
        final gate = Completer<int?>();
        fakeAssistantRepo.healthGate = gate;
        await tester.pumpWidget(
          buildTestableScreen(
            initialCredential: AssistantCredential(
              backendUrl: 'http://macbook.local:8765',
              bearerToken: 'fake_token',
              userId: 'test_user',
              displayName: 'User',
              pairedAt: DateTime(2026),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        expect(find.text('Laptop assistant unavailable'), findsOneWidget);
        gate.complete(1);
        await tester.pump();
        expect(find.text('Laptop assistant unavailable'), findsOneWidget);
        fakeAssistantRepo.healthGate = null;
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Laptop assistant is reachable'), findsOneWidget);
        expect(fakeAssistantRepo.healthCheckCount, 2);
        expect(fakeAssistantRepo.textQueryCount, 0);
      },
    );

    testWidgets('voice and typed controls have actionable accessible labels', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildTestableScreen());
        await tester.pumpAndSettle();
        await openOtherAssistant(tester);
        await tester.ensureVisible(
          find.byKey(AppKeys.assistantPushToTalkButton),
        );
        await tester.pump();
        final speak = find.semantics
            .byLabel('Speak to Vision AI')
            .evaluate()
            .single;
        expect(speak.flagsCollection.isButton, isTrue);
        expect(speak.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        await tester.ensureVisible(
          find.byKey(AppKeys.assistantTextInputToggle),
        );
        await tester.pump();
        final type = find.semantics
            .byLabel('Open text input as an alternative to voice')
            .evaluate()
            .single;
        type.owner!.performAction(type.id, SemanticsAction.tap);
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(AppKeys.assistantTextSubmitButton),
        );
        await tester.pump();
        final send = tester.getSemantics(
          find.byKey(AppKeys.assistantTextSubmitButton),
        );
        expect(
          send.getSemanticsData().tooltip,
          'Send typed question or command',
        );
        expect(send.flagsCollection.isButton, isTrue);
        expect(send.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('opens scanned text as an editable unsent draft', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableScreen(initialDraft: 'Scanned private text.'),
      );
      await tester.pumpAndSettle();
      await openOtherAssistant(tester);

      final input = tester.widget<TextField>(
        find.byKey(AppKeys.assistantTextInput),
      );
      expect(input.controller?.text, 'Scanned private text.');
      expect(fakeAssistantRepo.textQueryCount, 0);
    });

    testWidgets('renders screen title, status pill, push-to-talk button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();
      await openOtherAssistant(tester);

      expect(find.text(AppStrings.assistantTitle), findsOneWidget);
      expect(find.byKey(AppKeys.assistantPushToTalkButton), findsOneWidget);
      expect(find.text('Tap to speak'), findsOneWidget);
    });

    testWidgets('displays Not Paired banner when credential is missing', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();
      await openOtherAssistant(tester);

      expect(find.byKey(AppKeys.assistantNotPairedBanner), findsOneWidget);
      expect(
        find.text(
          'Offline voice and typed app controls are ready on this phone. '
          'Choose Gemini or the optional laptop for general conversation.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('toggles text input panel when "Type instead" is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();
      await openOtherAssistant(tester);

      expect(find.byKey(AppKeys.assistantTextInput), findsNothing);

      await tester.tap(find.byKey(AppKeys.assistantTextInputToggle));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.assistantTextInput), findsOneWidget);
      expect(find.byKey(AppKeys.assistantTextSubmitButton), findsOneWidget);
    });

    testWidgets('settings and connection action buttons have touch targets', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();
      await openOtherAssistant(tester);

      final settingsButton = tester.getRect(
        find.byKey(AppKeys.assistantSettingsButton),
      );
      final connButton = tester.getRect(
        find.byKey(AppKeys.assistantConnectionButton),
      );

      expect(settingsButton.width, greaterThanOrEqualTo(40.0));
      expect(settingsButton.height, greaterThanOrEqualTo(40.0));
      expect(connButton.width, greaterThanOrEqualTo(40.0));
      expect(connButton.height, greaterThanOrEqualTo(40.0));
    });

    testWidgets('supports 2× text scaling on a narrow Android viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: buildTestableScreen(),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
