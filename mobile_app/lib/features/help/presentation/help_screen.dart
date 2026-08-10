import 'package:flutter/material.dart';

import '../../../app/router/app_route.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  var _stepIndex = 0;

  static const _steps = <_HelpStep>[
    _HelpStep(
      icon: AppIcons.playCircle,
      title: 'Start Assistance',
      description:
          'Open Mobile Mode, tap Start Assistance, and grant camera permission when Android asks.',
    ),
    _HelpStep(
      icon: AppIcons.mode,
      title: 'Switch Modes',
      description:
          'Use Mode Selection for independent phone-camera assistance or a securely paired Raspberry Pi wearable.',
    ),
    _HelpStep(
      icon: AppIcons.notifications,
      title: 'Understand Alerts',
      description:
          'Alerts use estimated visual importance, offline audio, bounded vibration patterns, stability checks, and cooldowns.',
    ),
    _HelpStep(
      icon: AppIcons.bluetooth,
      title: 'Connect the Wearable',
      description:
          'Open Raspberry Pi Mode, search the local network or enter a local hostname, then pair using the short-lived code displayed by the Pi.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final isFirst = _stepIndex == 0;
    final isLast = _stepIndex == _steps.length - 1;

    return AppScreenScaffold(
      title: AppStrings.helpTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.help,
        items: AppBottomNavigation.aboutItems,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            'User Guide',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Step ${_stepIndex + 1} of ${_steps.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          container: true,
          label: '${step.title}. ${step.description}',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryOverlay10,
              border: Border.all(color: AppColors.primaryOverlay30, width: 2),
              borderRadius: BorderRadius.circular(AppRadii.extraLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    step.icon,
                    color: AppColors.primary,
                    size: AppSpacing.space10,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(step.description),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        Row(
          children: [
            Expanded(
              child: SecondaryActionButton(
                key: AppKeys.helpPreviousButton,
                label: 'Previous',
                onPressed: isFirst
                    ? null
                    : () => setState(() {
                        _stepIndex -= 1;
                      }),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: PrimaryActionButton(
                key: isLast ? AppKeys.helpDoneButton : AppKeys.helpNextButton,
                label: isLast ? 'Got It' : 'Next',
                icon: isLast ? AppIcons.selected : AppIcons.arrowForward,
                onPressed: () {
                  if (isLast) {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoute.home.path);
                    return;
                  }
                  setState(() {
                    _stepIndex += 1;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpStep {
  const _HelpStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
