import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/permission_providers.dart';
import '../../../app/router/app_route.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/enums/camera_permission_status.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(cameraPermissionControllerProvider.notifier).checkPermission();
    });
  }

  Future<void> _handleAllowAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final controller = ref.read(cameraPermissionControllerProvider.notifier);
    final status = await controller.requestPermission();

    if (!mounted) return;
    setState(() => _requesting = false);

    if (status.isGranted) {
      _announceStatus('Camera permission granted');
      Navigator.of(context).pushReplacementNamed(AppRoute.home.path);
    } else if (status.isPermanentlyDenied) {
      _announceStatus(
        'Camera permission permanently denied. Open device settings to allow camera access.',
      );
    } else {
      _announceStatus('Camera permission denied');
    }
  }

  Future<void> _handleOpenSettings() async {
    final controller = ref.read(cameraPermissionControllerProvider.notifier);
    await controller.openSettings();
  }

  void _announceStatus(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionStatus = ref.watch(cameraPermissionControllerProvider);

    return AppScreenScaffold(
      title: AppStrings.permissionsTitle,
      children: [
        Center(
          child: BrandIconBadge(
            icon: AppIcons.camera,
            label: 'Camera permission icon',
            size: 96,
            filled: true,
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          header: true,
          child: Text(
            'Allow Camera Access',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Mobile Mode needs camera access for local object detection. '
          'No images are uploaded, recorded, or shared.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.space5),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Local camera boundary',
          description:
              'No raw frames are uploaded, recorded, analyzed in the cloud, or attached to an account.',
        ),
        const SizedBox(height: AppSpacing.space4),
        _buildStatusNotice(permissionStatus),
        const SizedBox(height: AppSpacing.space6),
        ..._buildActions(permissionStatus),
      ],
    );
  }

  Widget _buildStatusNotice(CameraPermissionStatus status) {
    return switch (status) {
      CameraPermissionStatus.granted => const FeatureNoteCard(
        icon: AppIcons.selected,
        title: 'Permission granted',
        description: 'Camera access is available for Mobile Mode.',
      ),
      CameraPermissionStatus.permanentlyDenied => const ErrorNotice(
        title: 'Permission permanently denied',
        message:
            'Camera access was permanently denied. Open your device settings to allow camera access for this app.',
        icon: AppIcons.warning,
      ),
      CameraPermissionStatus.denied => const ErrorNotice(
        title: 'Permission denied',
        message: 'Camera access was denied. Tap Allow Access to try again.',
        icon: AppIcons.warning,
      ),
      CameraPermissionStatus.restricted => const ErrorNotice(
        title: 'Permission restricted',
        message:
            'Camera access is restricted by device policy. Contact your device administrator.',
        icon: AppIcons.warning,
      ),
      CameraPermissionStatus.unknown => const FeatureNoteCard(
        icon: AppIcons.camera,
        title: 'Permission not yet checked',
        description:
            'Tap Allow Access to grant camera permission for local object detection.',
      ),
    };
  }

  List<Widget> _buildActions(CameraPermissionStatus status) {
    final widgets = <Widget>[];

    if (status.isGranted) {
      widgets.add(
        PrimaryActionButton(
          key: AppKeys.permissionsContinueButton,
          label: 'Continue to Home',
          icon: AppIcons.play,
          semanticLabel: 'Camera permission granted. Continue to home.',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      widgets.add(
        PrimaryActionButton(
          key: const Key('permissions_open_settings_button'),
          label: 'Open Device Settings',
          icon: AppIcons.settings,
          semanticLabel: 'Open device settings to allow camera permission',
          onPressed: _handleOpenSettings,
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.space3));
      widgets.add(
        SecondaryActionButton(
          key: AppKeys.permissionsContinueButton,
          label: AppStrings.continueWithoutCamera,
          semanticLabel: '${AppStrings.continueWithoutCamera} to home',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
      );
    } else {
      widgets.add(
        PrimaryActionButton(
          key: AppKeys.permissionsAllowButton,
          label: AppStrings.allowAccess,
          icon: AppIcons.camera,
          semanticLabel: 'Allow camera access for local object detection',
          onPressed: _requesting ? null : _handleAllowAccess,
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.space3));
      widgets.add(
        SecondaryActionButton(
          key: AppKeys.permissionsContinueButton,
          label: AppStrings.continueWithoutCamera,
          semanticLabel: '${AppStrings.continueWithoutCamera} to home',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
      );
    }

    return widgets;
  }
}
