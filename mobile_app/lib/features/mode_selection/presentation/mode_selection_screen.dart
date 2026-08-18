import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_route.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/selection_components.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/enums/operating_mode.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final selectedMode = settings.preferredOperatingMode;

    return AppScreenScaffold(
      title: AppStrings.modeSelectionTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.modeSelection,
      ),
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            'Select Mode',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Choose phone-camera assistance or control a paired Raspberry Pi wearable on the local network.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.space5),
        StatusPill(
          label: 'Selected mode: ${selectedMode.label}',
          icon: AppIcons.selected,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.space6),
        SelectableInfoCard(
          key: AppKeys.selectMobileModeButton,
          title: OperatingMode.mobile.label,
          description:
              'Use the Android phone camera for offline on-device object detection.',
          icon: AppIcons.smartphone,
          selected: selectedMode == OperatingMode.mobile,
          status: selectedMode == OperatingMode.mobile
              ? 'Selected and available'
              : 'Available now',
          semanticLabel:
              '${OperatingMode.mobile.label}, ${selectedMode == OperatingMode.mobile ? 'selected' : 'not selected'}',
          onTap: () => controller.selectOperatingMode(OperatingMode.mobile),
        ),
        const SizedBox(height: AppSpacing.space4),
        SelectableInfoCard(
          key: AppKeys.selectRaspberryPiModeButton,
          title: OperatingMode.raspberryPi.label,
          description:
              'Use a paired local Raspberry Pi wearable for camera detection and Pi-owned feedback.',
          icon: AppIcons.bluetooth,
          selected: selectedMode == OperatingMode.raspberryPi,
          status: AppStrings.raspberryPiDeferred,
          semanticLabel:
              '${OperatingMode.raspberryPi.label}, ${selectedMode == OperatingMode.raspberryPi ? 'selected' : 'not selected'}, local wearable controls available',
          onTap: () =>
              controller.selectOperatingMode(OperatingMode.raspberryPi),
        ),
        const SizedBox(height: AppSpacing.space6),
        PrimaryActionButton(
          key: AppKeys.confirmModeButton,
          label: 'Confirm Mode',
          icon: AppIcons.selected,
          semanticLabel: 'Confirm selected ${selectedMode.label}',
          onPressed: () {
            final route = selectedMode == OperatingMode.mobile
                ? AppRoute.home.path
                : AppRoute.raspberryPi.path;
            Navigator.of(context).pushReplacementNamed(route);
          },
        ),
        const SizedBox(height: AppSpacing.space4),

        // Document Scanner — accessible from mode selection and by voice command
        const _DocumentScannerTile(),

        const SizedBox(height: AppSpacing.space4),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Local operation only',
          description:
              'Mobile inference stays on the phone. Wearable Mode uses only an authenticated connection to the paired Pi on the local network.',
        ),
      ],
    );
  }
}

/// Card that navigates to the OCR document scanner screen.
class _DocumentScannerTile extends StatelessWidget {
  const _DocumentScannerTile();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Scan Document — open the camera to read text from a document aloud',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: InkWell(
          key: const Key('ocr_scanner_tile'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushNamed(RoutePaths.ocrScanner),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOverlay20,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Document',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Point the camera at any document and the app will read the text aloud.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
