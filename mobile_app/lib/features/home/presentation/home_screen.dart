import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistance_controller.dart';
import '../../../app/providers.dart';
import '../../../app/router/app_route.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/voice_kernel/voice_kernel_providers.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/enums/operating_mode.dart';
import '../../../domain/enums/voice_feature_context.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final mode = settings.preferredOperatingMode;
    final assistance = ref.watch(assistanceControllerProvider);
    final assistanceController = ref.read(
      assistanceControllerProvider.notifier,
    );
    final assistanceState = assistance.state;

    // Set voice feature context for contextual command authorization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref
          .read(visionVoiceKernelProvider.notifier)
          .setFeatureContext(VoiceFeatureContext.home);
    });

    return AppScreenScaffold(
      title: AppStrings.homeTitle,
      showBackButton: false,
      trailing: IconButton(
        key: AppKeys.homeHelpButton,
        tooltip: AppStrings.openHelp,
        onPressed: () => Navigator.of(context).pushNamed(AppRoute.help.path),
        icon: const Icon(AppIcons.help),
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.home,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const BrandIconBadge(
              icon: AppIcons.visibility,
              label: '${AppStrings.appName} status icon',
              size: 64,
              filled: true,
            ),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    headingLevel: 2,
                    child: Text(
                      'Vision AI',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    'Offline Mobile Mode is ready for on-device object detection.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        StatusPill(
          label: 'Mobile assistance: ${assistanceState.label}',
          icon: assistanceState.isActive ? AppIcons.success : AppIcons.camera,
          color: assistanceState.isActive
              ? AppColors.success
              : AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.space5),
        _StatusGrid(
          children: [
            StatusSummaryCard(
              label: 'Current mode',
              value: mode.label,
              icon: switch (mode) {
                OperatingMode.mobile => AppIcons.smartphone,
                OperatingMode.raspberryPi => AppIcons.bluetooth,
              },
            ),
            StatusSummaryCard(
              label: 'Assistance',
              value: assistanceState.label,
              icon: assistanceState.isActive
                  ? AppIcons.play
                  : AppIcons.stopCircle,
              color: assistanceState.isActive
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        PrimaryActionButton(
          key: AppKeys.homeMobileAssistanceButton,
          label: AppStrings.openMobileAssistance,
          icon: AppIcons.play,
          semanticLabel:
              'Open Mobile Mode to start camera and object detection assistance.',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoute.mobileAssistance.path),
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.homeStopAssistanceButton,
          label: 'Stop Assistance',
          icon: AppIcons.stop,
          semanticLabel: assistanceState.canStop
              ? 'Stop the active Mobile Mode assistance session'
              : AppStrings.stopAssistanceUnavailable,
          onPressed: assistanceState.canStop
              ? assistanceController.stopAssistance
              : null,
        ),
        const SizedBox(height: AppSpacing.space6),
        _HomeActionGrid(),
        const SizedBox(height: AppSpacing.space6),
        const SafetyNotice(
          title: 'Safety reminder',
          messages: [AppStrings.safetyAid, AppStrings.safetyWhiteCane],
        ),
      ],
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final width = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.space3) / 2;

        return Wrap(
          spacing: AppSpacing.space3,
          runSpacing: AppSpacing.space3,
          children: [
            SizedBox(
              width: width,
              child: SecondaryActionButton(
                key: AppKeys.homeModeSelectionButton,
                label: 'Mode',
                icon: AppIcons.mode,
                semanticLabel: AppStrings.openModeSelection,
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRoute.modeSelection.path),
              ),
            ),
            SizedBox(
              width: width,
              child: SecondaryActionButton(
                key: AppKeys.homeRaspberryPiButton,
                label: 'Cap',
                icon: AppIcons.bluetooth,
                semanticLabel: AppStrings.openRaspberryPi,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoute.raspberryPi.path),
              ),
            ),
            SizedBox(
              width: width,
              child: SecondaryActionButton(
                key: AppKeys.homeAssistantButton,
                label: 'Assistant',
                icon: AppIcons.settingsVoice,
                semanticLabel:
                    'Open the voice assistant for app controls and questions',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoute.assistant.path),
              ),
            ),
            SizedBox(
              width: width,
              child: SecondaryActionButton(
                key: AppKeys.homeSettingsButton,
                label: 'Settings',
                icon: AppIcons.settings,
                semanticLabel: AppStrings.openSettings,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoute.settings.path),
              ),
            ),
            SizedBox(
              width: width,
              child: SecondaryActionButton(
                key: AppKeys.homeAboutSafetyButton,
                label: 'Safety',
                icon: AppIcons.info,
                semanticLabel: AppStrings.openAboutSafety,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoute.aboutSafety.path),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final width = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.space3) / 2;

        return Wrap(
          spacing: AppSpacing.space3,
          runSpacing: AppSpacing.space3,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

Color _mutedText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.mutedDarkText
      : AppColors.mutedLightText;
}
