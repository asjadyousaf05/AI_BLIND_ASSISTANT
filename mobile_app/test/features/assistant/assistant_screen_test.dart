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

  Widget buildTestableScreen({AssistantCredential? initialCredential}) {
    if (initialCredential != null) {
      fakeCredRepo.credential = initialCredential;
    }
    return ProviderScope(
      overrides: [
        assistantCredentialRepositoryProvider.overrideWithValue(fakeCredRepo),
        assistantRepositoryProvider.overrideWithValue(fakeAssistantRepo),
        microphonePermissionServiceProvider.overrideWithValue(fakePermService),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
          fakeSpeechRecognizer,
        ),
      ],
      child: const MaterialApp(home: AssistantScreen()),
    );
  }

  group('AssistantScreen UI & Accessibility', () {
    testWidgets('renders screen title, status pill, push-to-talk button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.assistantTitle), findsOneWidget);
      expect(find.byKey(AppKeys.assistantPushToTalkButton), findsOneWidget);
      expect(find.text('Tap to speak'), findsOneWidget);
    });

    testWidgets('displays Not Paired banner when credential is missing', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.assistantNotPairedBanner), findsOneWidget);
      expect(
        find.text(
          'Offline voice and typed app controls are ready on this phone. '
          'Connect the optional laptop only for general conversation.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('toggles text input panel when "Type instead" is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

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
