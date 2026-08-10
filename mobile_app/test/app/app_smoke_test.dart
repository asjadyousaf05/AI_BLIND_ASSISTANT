import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:ai_blind_assistant/domain/entities/app_settings.dart';
import 'package:ai_blind_assistant/domain/entities/detection_settings.dart';
import 'package:ai_blind_assistant/domain/entities/feedback_settings.dart';
import 'package:ai_blind_assistant/domain/enums/operating_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('WT-APP-001 root application builds and opens startup route', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AiBlindAssistantApp()));

    expect(find.text(AppStrings.startupTitle), findsWidgets);
    expect(find.text(AppStrings.continueToHome), findsOneWidget);
  });

  testWidgets(
    'WT-APP-002 saved accessibility preferences affect the whole app',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsControllerProvider.overrideWith(
              _AccessibilitySettingsController.new,
            ),
          ],
          child: const AiBlindAssistantApp(),
        ),
      );

      final context = tester.element(find.text(AppStrings.startupTitle).last);
      final mediaQuery = MediaQuery.of(context);
      final theme = Theme.of(context);
      expect(mediaQuery.textScaler.scale(1), 1.2);
      expect(mediaQuery.disableAnimations, isTrue);
      expect(theme.colorScheme.surface, const Color(0xffffffff));
      expect(theme.colorScheme.onSurface, const Color(0xff000000));
    },
  );
}

class _AccessibilitySettingsController extends AppSettingsController {
  @override
  AppSettings build() {
    return const AppSettings(
      preferredOperatingMode: OperatingMode.mobile,
      feedbackSettings: FeedbackSettings.defaults,
      detectionSettings: DetectionSettings.defaults,
      vibrationEnabled: true,
      highContrastEnabled: true,
      largeTextEnabled: true,
      reducedMotionEnabled: true,
    );
  }
}
