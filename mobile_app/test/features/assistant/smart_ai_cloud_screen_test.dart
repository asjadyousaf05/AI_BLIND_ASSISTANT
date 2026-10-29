import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_controller.dart';
import 'package:ai_blind_assistant/domain/entities/smart_ai_cloud_configuration.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_interaction_policy.dart';
import 'package:ai_blind_assistant/features/assistant/presentation/smart_ai_cloud_connection_card.dart';
import 'package:ai_blind_assistant/features/assistant/presentation/smart_ai_cloud_screen.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';
import 'assistant_controller_test.dart' show FakeMicrophonePermissionService;

void main() {
  late FakeSmartAiConfigurationRepository configuration;
  late FakeSmartAiService service;
  late FakeSmartAiAudioCoordinator audio;
  setUp(() {
    configuration = FakeSmartAiConfigurationRepository();
    service = FakeSmartAiService([]);
    audio = FakeSmartAiAudioCoordinator([]);
  });
  Widget page(Widget child, {double scale = 1}) => ProviderScope(
    overrides: [
      smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
        configuration,
      ),
      smartAiCloudServiceProvider.overrideWithValue(service),
      smartAiAudioCoordinatorProvider.overrideWithValue(audio),
      microphonePermissionServiceProvider.overrideWithValue(
        FakeMicrophonePermissionService(),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );

  testWidgets(
    'unconfigured circle is accessible, setup opens settings, local guide and cue work',
    (tester) async {
      var settings = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        page(
          SmartAiCloudScreen(openConnectionSettings: () async => settings++),
        ),
      );
      await tester.pumpAndSettle();
      final circle = find.byKey(const Key('smart_ai_voice_circle'));
      expect(circle, findsOneWidget);
      expect(
        tester
            .getSemantics(circle)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        false,
      );
      expect(find.text('Set up Smart AI on this phone'), findsOneWidget);
      expect(find.textContaining('cloud audio is enabled'), findsNothing);
      await tester.tap(find.byKey(const Key('smart_ai_setup')));
      await tester.pumpAndSettle();
      expect(settings, 1);
      final cue = find.text('Test listening vibration and sound');
      await tester.ensureVisible(cue);
      await tester.tap(cue);
      await tester.pumpAndSettle();
      expect(audio.recordingCues, 1);
      final help = find.text('Hear how to use Smart AI');
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(audio.spoken.single, contains('Set up Smart AI'));
      expect(service.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unconfigured layout supports narrow width and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      page(SmartAiCloudScreen(openConnectionSettings: () async {}), scale: 2),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Back to Home and Vision AI'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'requires explicit audio disclosure consent and never calls providers on save',
    (tester) async {
      await tester.pumpWidget(
        page(
          const Scaffold(
            body: SingleChildScrollView(child: SmartAiCloudConnectionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up personal Smart AI keys'));
      await tester.pumpAndSettle();
      final provider = find.byKey(const Key('smart_ai_provider_agent_router'));
      await tester.ensureVisible(provider);
      await tester.tap(provider);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(
        FilledButton,
        'Use Groq and AgentRouter for Smart AI',
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.textContaining('Smart AI Speak uploads'), findsOneWidget);
      final groq = find.byKey(const Key('smart_ai_groq_key'));
      final router = find.byKey(const Key('smart_ai_router_key'));
      expect(tester.widget<TextField>(groq).obscureText, true);
      expect(tester.widget<TextField>(router).obscureText, true);
      final groqController = tester.widget<TextField>(groq).controller!;
      final routerController = tester.widget<TextField>(router).controller!;
      await tester.ensureVisible(groq);
      await tester.enterText(groq, testSmartAiConfiguration.groqKey);
      await tester.ensureVisible(router);
      await tester.enterText(router, testSmartAiConfiguration.routerKey);
      final consent = find.byKey(const Key('smart_ai_cloud_consent'));
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(configuration.configuration!.isValid, true);
      expect(groqController.text, isEmpty);
      expect(routerController.text, isEmpty);
      expect(service.events, isEmpty);
      expect(find.textContaining('Provider access is checked'), findsOneWidget);
    },
  );

  testWidgets(
    'Groq setup needs one key and discloses Groq as the text destination',
    (tester) async {
      await tester.pumpWidget(
        page(
          const Scaffold(
            body: SingleChildScrollView(child: SmartAiCloudConnectionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up personal Smart AI keys'));
      await tester.pumpAndSettle();
      final groq = find.byKey(const Key('smart_ai_groq_key'));
      expect(find.byKey(const Key('smart_ai_router_key')), findsNothing);
      await tester.ensureVisible(groq);
      await tester.enterText(groq, testGroqSmartAiConfiguration.groqKey);
      final consent = find.byKey(const Key('smart_ai_cloud_consent'));
      expect(
        tester.widget<CheckboxListTile>(consent).title,
        isA<Text>().having(
          (t) => t.data,
          'destination',
          contains('conversation text to Groq'),
        ),
      );
      final save = find.widgetWithText(FilledButton, 'Use Groq for Smart AI');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        configuration.configuration!.answerProvider,
        SmartAiAnswerProvider.groq,
      );
      expect(configuration.configuration!.routerKey, isEmpty);
      expect(service.events, isEmpty);
    },
  );

  testWidgets(
    'switching to Groq reuses saved encrypted keys only after fresh consent',
    (tester) async {
      configuration.configuration = testSmartAiConfiguration;
      await tester.pumpWidget(
        page(
          const Scaffold(
            body: SingleChildScrollView(child: SmartAiCloudConnectionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace personal Smart AI keys'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      final save = find.widgetWithText(FilledButton, 'Use Groq for Smart AI');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      final consent = find.byKey(const Key('smart_ai_cloud_consent'));
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        configuration.configuration!.answerProvider,
        SmartAiAnswerProvider.groq,
      );
      expect(
        configuration.configuration!.groqKey,
        testSmartAiConfiguration.groqKey,
      );
      expect(
        configuration.configuration!.routerKey,
        testSmartAiConfiguration.routerKey,
      );
      expect(service.events, isEmpty);
    },
  );

  testWidgets(
    'cloud screen discloses audio before Speak and gives clear sequential status',
    (tester) async {
      configuration.configuration = testGroqSmartAiConfiguration;
      await tester.pumpWidget(
        page(SmartAiCloudScreen(openConnectionSettings: () async {})),
      );
      await tester.pumpAndSettle();
      final disclosure = find.textContaining(
        'Speak sends a temporary 16 kHz mono clip',
      );
      final speak = find.byKey(const Key('smart_ai_voice_circle'));
      expect(
        tester.getTopLeft(disclosure).dy,
        lessThan(tester.getTopLeft(speak).dy),
      );
      expect(find.text('Ready for your question'), findsOneWidget);
      expect(
        find.textContaining('conversation text goes to Groq.'),
        findsOneWidget,
      );
      expect(service.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Smart AI layout supports narrow width and double text without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      configuration.configuration = testGroqSmartAiConfiguration;
      await tester.pumpWidget(
        page(SmartAiCloudScreen(openConnectionSettings: () async {}), scale: 2),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Type a question'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'Read last answer aloud replays locally without another provider call',
    (tester) async {
      configuration.configuration = testGroqSmartAiConfiguration;
      await tester.pumpWidget(
        page(SmartAiCloudScreen(openConnectionSettings: () async {})),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartAiCloudScreen)),
      );
      await container
          .read(smartAiCloudControllerProvider.notifier)
          .sendText('A synthetic question');
      await tester.pumpAndSettle();
      service.events.clear();
      final replay = find.text('Read last answer aloud');
      await tester.ensureVisible(replay);
      await tester.tap(replay);
      await tester.pumpAndSettle();
      expect(audio.spoken.length, 2);
      expect(service.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goodbye invokes Home only after audio release and without an answer request',
    (tester) async {
      configuration.configuration = testGroqSmartAiConfiguration;
      var home = 0;
      await tester.pumpWidget(
        page(
          SmartAiCloudScreen(
            openConnectionSettings: () async {},
            onReturnHome: () => home++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartAiCloudScreen)),
      );
      await container
          .read(smartAiCloudControllerProvider.notifier)
          .sendText('goodbye smart ai');
      await tester.pumpAndSettle();
      expect(home, 1);
      expect(audio.events, contains('release'));
      expect(service.events, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'named guidance and language controls work without a provider request',
    (tester) async {
      configuration.configuration = testGroqSmartAiConfiguration;
      await tester.pumpWidget(
        page(SmartAiCloudScreen(openConnectionSettings: () async {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Speech language'), findsOneWidget);
      final english = find.widgetWithText(ChoiceChip, 'English');
      await tester.ensureVisible(english);
      await tester.tap(english);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartAiCloudScreen)),
      );
      expect(
        container.read(smartAiCloudControllerProvider).speechLanguage,
        SmartAiSpeechLanguage.english,
      );
      final help = find.text('Hear how to use Smart AI');
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(audio.spoken.single, contains('Hold the large microphone circle'));
      expect(service.events, isEmpty);
      expect(find.text('Test listening vibration and sound'), findsOneWidget);
      expect(find.text('Back to Home and Vision AI'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
