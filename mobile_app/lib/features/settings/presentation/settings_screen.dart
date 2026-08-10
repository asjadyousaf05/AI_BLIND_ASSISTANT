import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/selection_components.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/enums/detection_sensitivity.dart';
import '../../../domain/enums/feedback_mode.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return AppScreenScaffold(
      title: AppStrings.settingsTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.settings,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        const Text('All settings are saved locally on this device.'),
        const SizedBox(height: AppSpacing.space6),
        _SectionTitle(
          title: 'Feedback Mode',
          description: 'Choose alert channels for detected obstacles.',
        ),
        const SizedBox(height: AppSpacing.space3),
        _ChoiceGrid(
          children: [
            SettingChoiceCard<FeedbackMode>(
              key: AppKeys.settingsFeedbackAudioButton,
              value: FeedbackMode.audio,
              groupValue: settings.feedbackSettings.mode,
              title: FeedbackMode.audio.label,
              icon: AppIcons.volume,
              onChanged: controller.selectFeedbackMode,
            ),
            SettingChoiceCard<FeedbackMode>(
              key: AppKeys.settingsFeedbackVibrationButton,
              value: FeedbackMode.vibration,
              groupValue: settings.feedbackSettings.mode,
              title: FeedbackMode.vibration.label,
              icon: AppIcons.vibration,
              onChanged: controller.selectFeedbackMode,
            ),
            SettingChoiceCard<FeedbackMode>(
              key: AppKeys.settingsFeedbackBothButton,
              value: FeedbackMode.audioAndVibration,
              groupValue: settings.feedbackSettings.mode,
              title: FeedbackMode.audioAndVibration.label,
              icon: AppIcons.notifications,
              onChanged: controller.selectFeedbackMode,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        _SectionTitle(
          title: 'Detection Sensitivity',
          description: 'Choose the detection threshold preset.',
        ),
        const SizedBox(height: AppSpacing.space3),
        _ChoiceGrid(
          children: [
            SettingChoiceCard<DetectionSensitivity>(
              key: AppKeys.settingsSensitivityLowButton,
              value: DetectionSensitivity.low,
              groupValue: settings.detectionSettings.sensitivity,
              title: DetectionSensitivity.low.label,
              icon: AppIcons.visibility,
              onChanged: controller.selectDetectionSensitivity,
            ),
            SettingChoiceCard<DetectionSensitivity>(
              key: AppKeys.settingsSensitivityMediumButton,
              value: DetectionSensitivity.medium,
              groupValue: settings.detectionSettings.sensitivity,
              title: DetectionSensitivity.medium.label,
              icon: AppIcons.selected,
              onChanged: controller.selectDetectionSensitivity,
            ),
            SettingChoiceCard<DetectionSensitivity>(
              key: AppKeys.settingsSensitivityHighButton,
              value: DetectionSensitivity.high,
              groupValue: settings.detectionSettings.sensitivity,
              title: DetectionSensitivity.high.label,
              icon: AppIcons.warning,
              onChanged: controller.selectDetectionSensitivity,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        _SectionTitle(
          title: 'Vibration',
          description: 'Enable or disable vibration alerts independently.',
        ),
        const SizedBox(height: AppSpacing.space3),
        SwitchListTile(
          title: const Text('Vibration enabled'),
          subtitle: Text(settings.vibrationEnabled ? 'On' : 'Off'),
          value: settings.vibrationEnabled,
          onChanged: (value) => controller.setVibrationEnabled(value),
        ),
        const SizedBox(height: AppSpacing.space6),
        _SectionTitle(
          title: 'Announcement Cooldown',
          description: 'Seconds between repeated announcements (1–30).',
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: settings.feedbackSettings.announcementCooldownSeconds
                    .toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label:
                    '${settings.feedbackSettings.announcementCooldownSeconds}s',
                onChanged: (value) =>
                    controller.setAnnouncementCooldown(value.round()),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${settings.feedbackSettings.announcementCooldownSeconds}s',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),
        _SectionTitle(
          title: 'Accessibility',
          description: 'Adjust display preferences.',
        ),
        const SizedBox(height: AppSpacing.space3),
        SwitchListTile(
          title: const Text('High contrast'),
          value: settings.highContrastEnabled,
          onChanged: (value) => controller.setHighContrastEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Large text'),
          value: settings.largeTextEnabled,
          onChanged: (value) => controller.setLargeTextEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Reduced motion'),
          value: settings.reducedMotionEnabled,
          onChanged: (value) => controller.setReducedMotionEnabled(value),
        ),
        const SizedBox(height: AppSpacing.space6),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Local-only settings',
          description:
              'No account, remote profile, analytics, or cloud synchronization is used.',
        ),
        const SizedBox(height: AppSpacing.space6),
        Center(
          child: SecondaryActionButton(
            key: AppKeys.settingsCancelButton,
            label: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(description),
      ],
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 1;
        final spacing = columns == 1 ? 0.0 : AppSpacing.space3;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.space3,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
