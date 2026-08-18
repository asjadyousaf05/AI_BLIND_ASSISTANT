import 'package:flutter/material.dart';

import '../../../app/router/app_route.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      title: AppStrings.startupTitle,
      showAppBar: false,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            key: AppKeys.startupHelpButton,
            tooltip: AppStrings.openHelp,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoute.help.path),
            icon: const Icon(AppIcons.help),
          ),
        ),
        const SizedBox(height: AppSpacing.space10),
        Center(
          child: BrandIconBadge(
            icon: AppIcons.visibility,
            label: '${AppStrings.appName} logo',
            filled: true,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        Semantics(
          headingLevel: 1,
          child: Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          AppStrings.startupDescription,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: _mutedText(context)),
        ),
        const SizedBox(height: AppSpacing.space8),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Offline and private',
          description:
              'Camera frames stay on this device. The app does not use cloud processing, analytics, upload, or video recording.',
        ),
        const SizedBox(height: AppSpacing.space8),
        PrimaryActionButton(
          key: AppKeys.startupContinueButton,
          label: AppStrings.continueToHome,
          icon: AppIcons.arrowForward,
          semanticLabel: '${AppStrings.continueToHome} to home',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          'Use TalkBack to explore every control, then open Mobile Mode from Home to start assistance.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _mutedText(context)),
        ),
      ],
    );
  }
}

Color _mutedText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.mutedDarkText
      : AppColors.mutedLightText;
}
