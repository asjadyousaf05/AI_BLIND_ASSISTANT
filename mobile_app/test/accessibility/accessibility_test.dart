import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:ai_blind_assistant/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('WT-ACC-001 important controls expose meaningful labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        const ProviderScope(child: AiBlindAssistantApp()),
      );

      expect(find.bySemanticsLabel(AppStrings.continueToHome), findsOneWidget);

      await tester.ensureVisible(find.byKey(AppKeys.startupContinueButton));
      await tester.tap(find.byKey(AppKeys.startupContinueButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(AppKeys.homeModeSelectionButton));
      expect(find.bySemanticsLabel(AppStrings.openModeSelection), findsWidgets);
      expect(
        find.bySemanticsLabel(
          'Open Mobile Mode to start camera and object detection assistance.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(AppStrings.openSettings), findsOneWidget);
      expect(find.bySemanticsLabel(AppStrings.openAboutSafety), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('WT-ACC-002 representative screen supports large text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: HomeScreen(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.homeTitle), findsWidgets);
  });

  testWidgets('WT-ACC-003 primary flow meets Flutter Android guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        const ProviderScope(child: AiBlindAssistantApp()),
      );
      await tester.pumpAndSettle();

      await _expectAndroidAccessibilityGuidelines(tester);

      await tester.ensureVisible(find.byKey(AppKeys.startupContinueButton));
      await tester.tap(find.byKey(AppKeys.startupContinueButton));
      await tester.pumpAndSettle();

      await _expectAndroidAccessibilityGuidelines(tester);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _expectAndroidAccessibilityGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
