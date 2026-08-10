import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_route.dart';
import '../../../app/wearable_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';

class ConnectionErrorScreen extends ConsumerWidget {
  const ConnectionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(wearableControllerProvider);
    final controller = ref.read(wearableControllerProvider.notifier);
    final failure = viewState.failure;
    final status = WearableController.statusLabelFor(viewState.session.phase);
    final recovery = WearableController.recoveryMessageFor(failure);

    return AppScreenScaffold(
      title: AppStrings.connectionErrorTitle,
      children: [
        Center(
          child: BrandIconBadge(
            icon: AppIcons.wifiOff,
            label: 'Raspberry Pi disconnected icon',
            size: 96,
            square: true,
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          header: true,
          child: Text(
            'Connection Failed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          failure?.userMessage ??
              'The phone is not currently connected to the local wearable.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.space5),
        StatusPill(
          label: status,
          icon: viewState.session.phase.isConnected
              ? AppIcons.success
              : AppIcons.wifiOff,
          color: viewState.session.phase.isConnected
              ? AppColors.success
              : AppColors.error,
        ),
        const SizedBox(height: AppSpacing.space5),
        ErrorNotice(
          title: 'Recovery guidance',
          message: recovery,
          icon: AppIcons.warning,
        ),
        const SizedBox(height: AppSpacing.space4),
        FeatureNoteCard(
          icon: AppIcons.info,
          title: 'Error code',
          description: failure?.code ?? 'NO_ACTIVE_WEARABLE_FAILURE',
        ),
        const SizedBox(height: AppSpacing.space6),
        PrimaryActionButton(
          key: AppKeys.connectionRetryButton,
          label: AppStrings.retryConnection,
          icon: AppIcons.refresh,
          semanticLabel: 'Retry local Raspberry Pi discovery or connection',
          onPressed: viewState.canRunAction ? controller.retry : null,
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          label: 'Back to Wearable Controls',
          icon: AppIcons.bluetooth,
          semanticLabel: 'Return to Raspberry Pi setup and controls',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.connectionSwitchMobileButton,
          label: AppStrings.switchToMobile,
          icon: AppIcons.smartphone,
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
      ],
    );
  }
}
