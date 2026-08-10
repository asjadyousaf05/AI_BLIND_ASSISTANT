import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';

class AboutSafetyScreen extends StatelessWidget {
  const AboutSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      title: AppStrings.aboutSafetyTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.aboutSafety,
        items: AppBottomNavigation.aboutItems,
      ),
      children: [
        Center(
          child: BrandIconBadge(
            icon: AppIcons.accessibility,
            label: '${AppStrings.appName} accessibility icon',
            size: 88,
            square: true,
            filled: true,
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          header: true,
          child: Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          'Version 1.0.0+1',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.space5),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Offline Ready',
          description:
              'The app is designed for local processing without raw camera frames leaving the device.',
        ),
        const SizedBox(height: AppSpacing.space3),
        const FeatureNoteCard(
          icon: AppIcons.accessibility,
          title: 'Accessibility First',
          description:
              'Native Flutter widgets, semantic labels, large touch targets, and TalkBack-compatible routes are required from the baseline.',
        ),
        const SizedBox(height: AppSpacing.space3),
        const FeatureNoteCard(
          icon: AppIcons.warning,
          title: 'Bounded Alerts',
          description:
              'Speech and vibration alerts use stability checks, bounded patterns, prioritization, and cooldowns rather than continuous feedback.',
        ),
        const SizedBox(height: AppSpacing.space6),
        const SafetyNotice(
          title: 'Important safety limitations',
          messages: [
            AppStrings.safetyAid,
            AppStrings.safetyWhiteCane,
            AppStrings.safetyAccuracy,
          ],
        ),
      ],
    );
  }
}
