import 'dart:async';

import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/app/assistance_controller.dart';
import 'package:ai_blind_assistant/app/router/app_route.dart';
import 'package:ai_blind_assistant/app/router/app_router.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/app/theme/app_theme.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:ai_blind_assistant/core/widgets/selection_components.dart';
import 'package:ai_blind_assistant/domain/enums/detection_sensitivity.dart';
import 'package:ai_blind_assistant/domain/enums/feedback_mode.dart';
import 'package:ai_blind_assistant/domain/enums/mobile_assistance_state.dart';
import 'package:ai_blind_assistant/features/mobile_assistance/presentation/mobile_assistance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('WT-UI-001 migrated home exposes primary actions and safety', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AiBlindAssistantApp()));

    await tester.ensureVisible(find.byKey(AppKeys.startupContinueButton));
    await tester.tap(find.byKey(AppKeys.startupContinueButton));
    await tester.pumpAndSettle();

    expect(find.text('Vision AI'), findsOneWidget);
    expect(find.byKey(AppKeys.homeMobileAssistanceButton), findsOneWidget);
    expect(find.byKey(AppKeys.homeStopAssistanceButton), findsOneWidget);
    expect(find.byKey(AppKeys.homeAssistantButton), findsOneWidget);
    expect(find.textContaining('assistive aid'), findsWidgets);
  });

  testWidgets('WT-UI-002 mode selection updates selected state and routes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _RouteHarness(initialRoute: AppRoute.modeSelection.path),
      );

      expect(find.text('SELECTED MODE: MOBILE MODE'), findsOneWidget);
      expect(
        _modeChoice(tester, AppKeys.selectMobileModeButton).selected,
        isTrue,
      );

      await tester.tap(find.byKey(AppKeys.selectRaspberryPiModeButton));
      await tester.pumpAndSettle();

      expect(find.text('SELECTED MODE: RASPBERRY PI MODE'), findsOneWidget);
      expect(
        _modeChoice(tester, AppKeys.selectRaspberryPiModeButton).selected,
        isTrue,
      );

      await tester.ensureVisible(find.byKey(AppKeys.confirmModeButton));
      await tester.tap(find.byKey(AppKeys.confirmModeButton));
      await tester.pumpAndSettle();

      expect(find.text('Raspberry Cap'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('WT-UI-003 mobile assistance requests and explains permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouteHarness(initialRoute: AppRoute.mobileAssistance.path),
    );

    expect(find.text('Camera permission required'), findsOneWidget);
    expect(
      find.text(
        'Grant camera permission before starting assistance. Tap Permission Details below.',
      ),
      findsOneWidget,
    );
    expect(
      _filledButtonFor(tester, AppKeys.mobileStartAssistanceButton).onPressed,
      isNotNull,
    );
    expect(
      _filledButtonFor(tester, AppKeys.mobileStopAssistanceButton).onPressed,
      isNull,
    );
    expect(
      _filledButtonFor(tester, AppKeys.mobilePauseAssistanceButton).onPressed,
      isNull,
    );

    await tester.ensureVisible(find.byKey(AppKeys.mobilePermissionButton));
    await tester.tap(find.byKey(AppKeys.mobilePermissionButton));
    await tester.pumpAndSettle();

    expect(find.text('Permission not yet checked'), findsOneWidget);
    expect(
      _filledButtonFor(tester, AppKeys.permissionsAllowButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('WT-UI-004 settings choices update in-memory visual state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        _RouteHarness(initialRoute: AppRoute.settings.path),
      );

      expect(
        _feedbackChoice(tester, AppKeys.settingsFeedbackBothButton).groupValue,
        FeedbackMode.audioAndVibration,
      );
      expect(
        _sensitivityChoice(
          tester,
          AppKeys.settingsSensitivityMediumButton,
        ).groupValue,
        DetectionSensitivity.medium,
      );

      await tester.tap(find.byKey(AppKeys.settingsFeedbackAudioButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(AppKeys.settingsSensitivityHighButton),
      );
      await tester.tap(find.byKey(AppKeys.settingsSensitivityHighButton));
      await tester.pumpAndSettle();

      expect(
        _feedbackChoice(tester, AppKeys.settingsFeedbackAudioButton).groupValue,
        FeedbackMode.audio,
      );
      expect(
        _sensitivityChoice(
          tester,
          AppKeys.settingsSensitivityHighButton,
        ).groupValue,
        DetectionSensitivity.high,
      );
      expect(
        find.text('All settings are saved locally on this device.'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('WT-UI-005 Raspberry Pi initial state is explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _RouteHarness(initialRoute: AppRoute.raspberryPi.path),
    );

    expect(find.text('Raspberry Cap'), findsOneWidget);
    expect(find.text('No wearable configured'), findsWidgets);
    expect(
      _filledButtonFor(tester, AppKeys.raspberryPiScanButton).onPressed,
      isNotNull,
    );
    expect(find.byKey(AppKeys.raspberryPiConnectButton), findsNothing);
    expect(find.byKey(AppKeys.raspberryPiErrorButton), findsNothing);
  });

  testWidgets('WT-UI-006 help guide moves through steps and returns home', (
    tester,
  ) async {
    await tester.pumpWidget(_RouteHarness(initialRoute: AppRoute.help.path));

    expect(find.text('Start Assistance'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.helpNextButton));
    await tester.pumpAndSettle();
    expect(find.text('Switch Modes'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.helpNextButton));
    await tester.pumpAndSettle();
    expect(find.text('Understand Alerts'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.helpNextButton));
    await tester.pumpAndSettle();
    expect(find.text('Connect the Wearable'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.helpDoneButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.homeTitle), findsWidgets);
  });

  testWidgets('WT-UI-007 migrated routes tolerate large text on mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final route in AppRoute.values) {
      await tester.pumpWidget(
        _RouteHarness(
          initialRoute: route.path,
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(route.title),
        findsWidgets,
        reason: 'Route ${route.path} must expose its screen title.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Route ${route.path} must not overflow at 2× text scale.',
      );
    }
  });

  testWidgets('WT-UI-009 active Mobile Mode exposes a working pause control', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistanceControllerProvider.overrideWith(
            _PauseProbeAssistanceController.new,
          ),
        ],
        child: MaterialApp(
          initialRoute: RoutePaths.mobileAssistance,
          onGenerateRoute: AppRouter.onGenerateRoute,
          theme: AppTheme.light,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(AppKeys.mobilePauseAssistanceButton));
    final pauseButton = _filledButtonFor(
      tester,
      AppKeys.mobilePauseAssistanceButton,
    );
    expect(pauseButton.onPressed, isNotNull);
    await tester.tap(find.byKey(AppKeys.mobilePauseAssistanceButton));
    await tester.pump();

    final context = tester.element(find.byType(MobileAssistanceScreen));
    final controller =
        ProviderScope.containerOf(
              context,
            ).read(assistanceControllerProvider.notifier)
            as _PauseProbeAssistanceController;
    expect(controller.pauseCalled, isTrue);
    expect(find.text('PAUSED'), findsWidgets);
  });

  testWidgets(
    'WT-UI-008 leaving active Mobile Mode releases after route disposal',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistanceControllerProvider.overrideWith(
              _DisposeProbeAssistanceController.new,
            ),
          ],
          child: MaterialApp(
            initialRoute: RoutePaths.mobileAssistance,
            onGenerateRoute: AppRouter.onGenerateRoute,
            theme: AppTheme.light,
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(MobileAssistanceScreen));
      final controller =
          ProviderScope.containerOf(
                context,
              ).read(assistanceControllerProvider.notifier)
              as _DisposeProbeAssistanceController;

      unawaited(Navigator.of(context).pushReplacementNamed(RoutePaths.home));
      await tester.pumpAndSettle();

      expect(controller.detachCalled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

FilledButton _filledButtonFor(WidgetTester tester, Key key) {
  return tester.widget<FilledButton>(
    find.descendant(of: find.byKey(key), matching: find.byType(FilledButton)),
  );
}

class _RouteHarness extends StatelessWidget {
  const _RouteHarness({required this.initialRoute, this.textScaler});

  final String initialRoute;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        initialRoute: initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        key: ValueKey(initialRoute),
        builder: (context, child) {
          if (textScaler == null) {
            return child ?? const SizedBox.shrink();
          }
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _DisposeProbeAssistanceController extends AssistanceController {
  bool detachCalled = false;

  @override
  AssistanceSessionState build() {
    return const AssistanceSessionState(state: MobileAssistanceState.active);
  }

  @override
  Future<void> handleDetach() async {
    detachCalled = true;
    state = const AssistanceSessionState(state: MobileAssistanceState.idle);
  }
}

class _PauseProbeAssistanceController extends AssistanceController {
  bool pauseCalled = false;

  @override
  AssistanceSessionState build() {
    return const AssistanceSessionState(state: MobileAssistanceState.active);
  }

  @override
  Future<void> pauseAssistance() async {
    pauseCalled = true;
    state = const AssistanceSessionState(state: MobileAssistanceState.paused);
  }

  @override
  Future<void> handleDetach() async {}
}

SettingChoiceCard<FeedbackMode> _feedbackChoice(WidgetTester tester, Key key) {
  return tester.widget<SettingChoiceCard<FeedbackMode>>(find.byKey(key));
}

SelectableInfoCard _modeChoice(WidgetTester tester, Key key) {
  return tester.widget<SelectableInfoCard>(find.byKey(key));
}

SettingChoiceCard<DetectionSensitivity> _sensitivityChoice(
  WidgetTester tester,
  Key key,
) {
  return tester.widget<SettingChoiceCard<DetectionSensitivity>>(
    find.byKey(key),
  );
}
