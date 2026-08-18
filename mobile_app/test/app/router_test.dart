import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/app/router/app_route.dart';
import 'package:ai_blind_assistant/app/router/app_router.dart';
import 'package:ai_blind_assistant/app/theme/app_theme.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('WT-ROUTER-001 initial route can navigate to home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AiBlindAssistantApp()));

    await tester.ensureVisible(find.byKey(AppKeys.startupContinueButton));
    await tester.tap(find.byKey(AppKeys.startupContinueButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeTitle), findsWidgets);
    expect(find.byKey(AppKeys.homeModeSelectionButton), findsOneWidget);
  });

  for (final route in AppRoute.values) {
    testWidgets('WT-ROUTER-002 route ${route.path} renders ${route.title}', (
      tester,
    ) async {
      await tester.pumpWidget(_RouteHarness(initialRoute: route.path));
      await tester.pumpAndSettle();

      expect(find.text(route.title), findsWidgets);
    });
  }

  testWidgets('WT-ROUTER-003 unknown route is handled safely', (tester) async {
    await tester.pumpWidget(const _RouteHarness(initialRoute: '/missing'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.pageNotFoundTitle), findsWidgets);
    expect(find.textContaining('/missing'), findsOneWidget);
    expect(find.text(AppStrings.returnHome), findsOneWidget);
  });

  testWidgets('WT-ROUTER-005 assistant is a standard named route', (
    tester,
  ) async {
    await tester.pumpWidget(const _RouteHarness(initialRoute: '/assistant'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.assistantTitle), findsWidgets);
    expect(find.byKey(AppKeys.assistantPushToTalkButton), findsOneWidget);
  });

  testWidgets('WT-ROUTER-004 back navigation returns from settings to home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AiBlindAssistantApp()));
    await tester.ensureVisible(find.byKey(AppKeys.startupContinueButton));
    await tester.tap(find.byKey(AppKeys.startupContinueButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(AppKeys.homeSettingsButton));
    await tester.tap(find.byKey(AppKeys.homeSettingsButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsTitle), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeTitle), findsWidgets);
  });
}

class _RouteHarness extends StatelessWidget {
  const _RouteHarness({required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        initialRoute: initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
      ),
    );
  }
}
