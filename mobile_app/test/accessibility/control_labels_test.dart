import 'dart:ui' show SemanticsAction;

import 'package:ai_blind_assistant/core/widgets/action_buttons.dart';
import 'package:ai_blind_assistant/core/widgets/app_bottom_navigation.dart';
import 'package:ai_blind_assistant/core/widgets/selection_components.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings choices and adjustable cooldown have context and units',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsScreen())),
        );
        final choices = {
          AppKeys.settingsFeedbackAudioButton: 'Use audio alerts',
          AppKeys.settingsFeedbackVibrationButton: 'Use vibration alerts',
          AppKeys.settingsFeedbackBothButton: 'Use audio and vibration alerts',
          AppKeys.settingsSensitivityLowButton: 'Set low detection sensitivity',
          AppKeys.settingsSensitivityMediumButton:
              'Set medium detection sensitivity',
          AppKeys.settingsSensitivityHighButton:
              'Set high detection sensitivity',
        };
        for (final entry in choices.entries) {
          await tester.ensureVisible(find.byKey(entry.key));
          await tester.pump();
          final node = find.semantics.byLabel(entry.value).evaluate().single;
          expect(node.label, entry.value);
          expect(node.flagsCollection.isSelected.toBoolOrNull(), isNotNull);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
        }
        await tester.ensureVisible(find.byType(Slider));
        await tester.pump();
        final cooldown = find.semantics
            .byLabel('Announcement cooldown')
            .evaluate()
            .single;
        expect(cooldown.getSemanticsData().value, contains('seconds'));
        expect(
          cooldown.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
        );
        expect(
          cooldown.getSemanticsData().hasAction(SemanticsAction.decrease),
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'navigation names wearable destination and supports accessible taps',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        String? openedRoute;
        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(
              bottomNavigationBar: AppBottomNavigation(
                selectedRoutePath: RoutePaths.home,
              ),
            ),
            onGenerateRoute: (settings) {
              openedRoute = settings.name;
              return MaterialPageRoute<void>(builder: (_) => const Scaffold());
            },
          ),
        );
        final node = find.semantics
            .byLabel(RegExp('Wearable'))
            .evaluate()
            .single;
        expect(node.label, contains('Wearable'));
        expect(node.label, isNot(contains('Cap')));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(openedRoute, RoutePaths.raspberryPi);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'action labels are announced once and activate through semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var activated = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PrimaryActionButton(
                    label: 'Start',
                    semanticLabel: 'Start mobile assistance',
                    onPressed: () => activated++,
                  ),
                  const SecondaryActionButton(
                    label: 'Stop',
                    semanticLabel: 'Stop mobile assistance',
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        );
        final start = tester.getSemantics(
          find.bySemanticsLabel('Start mobile assistance'),
        );
        expect(start.label, 'Start mobile assistance');
        expect(start.flagsCollection.isButton, isTrue);
        expect(start.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        start.owner!.performAction(start.id, SemanticsAction.tap);
        expect(activated, 1);

        final stop = tester.getSemantics(
          find.bySemanticsLabel('Stop mobile assistance'),
        );
        expect(stop.label, 'Stop mobile assistance');
        expect(stop.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
        expect(stop.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('choices expose one label and selection state independently', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var selected = 'audio';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  for (final value in ['audio', 'vibration'])
                    SettingChoiceCard<String>(
                      title: value,
                      semanticLabel: 'Use $value alerts',
                      value: value,
                      groupValue: selected,
                      icon: Icons.notifications,
                      onChanged: (value) => setState(() => selected = value),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final audio = tester.getSemantics(
        find.bySemanticsLabel('Use audio alerts'),
      );
      expect(audio.label, 'Use audio alerts');
      expect(audio.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      final vibration = tester.getSemantics(
        find.bySemanticsLabel('Use vibration alerts'),
      );
      expect(vibration.flagsCollection.isSelected.toBoolOrNull(), isFalse);
      vibration.owner!.performAction(vibration.id, SemanticsAction.tap);
      await tester.pump();
      expect(selected, 'vibration');
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Use vibration alerts'))
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });
}
