import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/features/assistant/presentation/assistant_connection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/gemini_fakes.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'assistant_controller_test.dart';

void main() {
  late FakeGeminiConfigurationRepository configuration;
  late FakeAssistantCredentialRepository pairing;
  late FakeGeminiConversationService gemini;
  setUp(() {
    configuration = FakeGeminiConfigurationRepository();
    pairing = FakeAssistantCredentialRepository();
    gemini = FakeGeminiConversationService();
  });
  Widget screen({double scale = 1}) => ProviderScope(
    overrides: [
      smartAiCloudConfigurationRepositoryProvider.overrideWithValue(
        FakeSmartAiConfigurationRepository(),
      ),
      geminiConfigurationRepositoryProvider.overrideWithValue(configuration),
      geminiConversationServiceProvider.overrideWithValue(gemini),
      assistantCredentialRepositoryProvider.overrideWithValue(pairing),
      speechOutputServiceProvider.overrideWithValue(FakeSpeechOutputService()),
      onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
        FakeOnDeviceSpeechRecognitionService(),
      ),
      audioRecorderServiceProvider.overrideWithValue(
        FakeAudioRecorderService(),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const AssistantConnectionScreen(),
    ),
  );

  testWidgets(
    'requires disclosure consent, obscures the key and never sends on save',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final enable = find.widgetWithText(
        FilledButton,
        'Use Gemini without laptop',
      );
      expect(tester.widget<FilledButton>(enable).onPressed, isNull);
      final keyField = find.byKey(const Key('gemini_api_key'));
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      expect(find.textContaining('Free-tier content may'), findsOneWidget);
      await tester.ensureVisible(keyField);
      await tester.enterText(keyField, testGeminiConfiguration.apiKey);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(enable);
      await tester.tap(enable);
      await tester.pumpAndSettle();
      expect(
        configuration.configuration?.apiKey,
        testGeminiConfiguration.apiKey,
      );
      expect(tester.widget<TextField>(keyField).controller!.text, isEmpty);
      expect(gemini.queries, isEmpty);
      final remove = find.text('Remove Gemini key');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(configuration.configuration, isNull);
    },
  );

  testWidgets('restores saved laptop address instead of a historical default', (
    tester,
  ) async {
    pairing.credential = AssistantCredential(
      backendUrl: 'http://192.168.79.21:8765',
      bearerToken: 'synthetic-token',
      userId: 'synthetic',
      displayName: '',
      pairedAt: DateTime(2026),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    final host = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField && widget.controller?.text == '192.168.79.21',
    );
    expect(host, findsOneWidget);
    expect(find.text('This Mac — Wi-Fi Direct'), findsNothing);
  });

  testWidgets('Gemini setup remains usable at narrow width and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use Gemini without laptop'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
