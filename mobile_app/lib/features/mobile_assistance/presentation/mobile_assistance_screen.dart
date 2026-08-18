import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistance_controller.dart';
import '../../../app/detection_providers.dart';
import '../../../app/feedback_providers.dart';
import '../../../app/permission_providers.dart';
import '../../../app/providers.dart';
import '../../../app/risk_providers.dart';
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
import '../../../domain/enums/camera_permission_status.dart';
import '../../../domain/enums/assistance_failure_kind.dart';
import '../../../domain/enums/mobile_assistance_state.dart';
import '../../../domain/enums/voice_feature_context.dart';
import 'camera_preview_widget.dart';

class MobileAssistanceScreen extends ConsumerStatefulWidget {
  const MobileAssistanceScreen({super.key});

  @override
  ConsumerState<MobileAssistanceScreen> createState() =>
      _MobileAssistanceScreenState();
}

class _MobileAssistanceScreenState
    extends ConsumerState<MobileAssistanceScreen> {
  late final AssistanceController _assistanceController;
  late final VisionVoiceKernelV3 _voiceKernel;

  @override
  void initState() {
    super.initState();
    _assistanceController = ref.read(assistanceControllerProvider.notifier);
    _voiceKernel = ref.read(visionVoiceKernelProvider.notifier);
    // Riverpod providers must not be changed while the route is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceKernel.setFeatureContext(VoiceFeatureContext.mobileDetection);
      unawaited(
        ref.read(cameraPermissionControllerProvider.notifier).checkPermission(),
      );
    });
  }

  @override
  void dispose() {
    // Provider state cannot be changed synchronously while Flutter is
    // unmounting this route. The controller is application-scoped, so it is
    // safe to capture it and release the pipeline immediately after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceKernel.setFeatureContext(VoiceFeatureContext.unknown);
    });
    if (_assistanceController.requiresDetachCleanup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_assistanceController.handleDetach());
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(assistanceControllerProvider);
    final permissionStatus = ref.watch(cameraPermissionControllerProvider);
    final detections = ref.watch(detectionResultsProvider);
    final alerts = ref.watch(obstacleAlertsProvider);
    final feedbackActive = ref.watch(feedbackControllerProvider);
    final feedbackWarning = ref
        .read(feedbackControllerProvider.notifier)
        .lastWarning;
    final settings = ref.watch(appSettingsControllerProvider);

    final assistState = session.state;
    final hasPermission = permissionStatus.isGranted;
    final isActive = assistState.isActive;
    final isBusy = assistState.isBusy;
    final canStart =
        assistState.canStart && !permissionStatus.isPermanentlyDenied;
    final canStop = assistState.canStop;
    final canPause = assistState.canPause;

    return AppScreenScaffold(
      title: AppStrings.mobileAssistanceTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.home,
      ),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const BrandIconBadge(
              icon: AppIcons.camera,
              label: 'Mobile camera assistance icon',
              size: 72,
              square: true,
            ),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    headingLevel: 2,
                    child: Text(
                      'Mobile Mode',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _getStatusDescription(assistState, hasPermission),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space6),

        // Status pill
        _buildStatusPill(assistState, session.failureKind, permissionStatus),
        const SizedBox(height: AppSpacing.space5),

        // Camera preview (only when permission granted and camera is active)
        if (hasPermission &&
            (isActive || assistState == MobileAssistanceState.paused)) ...[
          const CameraPreviewWidget(),
          const SizedBox(height: AppSpacing.space5),
        ],

        // Status grid
        _AssistanceStatusGrid(
          assistState: assistState,
          hasPermission: hasPermission,
          detectionCount: detections.length,
          alertCount: alerts.length,
          feedbackActive: feedbackActive,
          feedbackMode: settings.feedbackSettings.mode.label,
        ),
        const SizedBox(height: AppSpacing.space5),

        if (alerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space5),
            child: Semantics(
              liveRegion: true,
              label: 'Current detection alert',
              child: StatusSummaryCard(
                label: 'Current alert',
                value: alerts.first.spokenDescription,
                icon: AppIcons.warning,
                color: AppColors.warning,
              ),
            ),
          ),

        // Error message
        if (session.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space5),
            child: ErrorNotice(
              title: 'Assistance Error',
              message: session.errorMessage!,
              icon: AppIcons.warning,
            ),
          ),

        if (feedbackWarning != null && session.errorMessage == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space5),
            child: ErrorNotice(
              title: 'Limited feedback',
              message: feedbackWarning,
              icon: AppIcons.warning,
            ),
          ),

        // Permission warning
        if (!hasPermission && session.errorMessage == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space5),
            child: ErrorNotice(
              title: 'Camera permission required',
              message: permissionStatus.isPermanentlyDenied
                  ? 'Permission permanently denied. Open device settings to grant camera access.'
                  : 'Grant camera permission before starting assistance. Tap Permission Details below.',
              icon: AppIcons.warning,
            ),
          ),

        // Start button
        PrimaryActionButton(
          key: AppKeys.mobileStartAssistanceButton,
          label: _getStartButtonLabel(assistState, isActive, isBusy),
          icon: isBusy ? AppIcons.refresh : AppIcons.play,
          semanticLabel: _getStartButtonSemantic(
            assistState,
            hasPermission,
            isActive,
            isBusy,
          ),
          onPressed: canStart && !isBusy
              ? () => ref
                    .read(assistanceControllerProvider.notifier)
                    .startAssistance()
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),

        SecondaryActionButton(
          key: AppKeys.mobilePauseAssistanceButton,
          label: 'Pause Assistance',
          icon: Icons.pause,
          semanticLabel: canPause
              ? 'Pause camera and object detection and release camera resources'
              : 'Pause assistance unavailable while detection is inactive',
          onPressed: canPause
              ? () => ref
                    .read(assistanceControllerProvider.notifier)
                    .pauseAssistance()
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),

        // Stop button
        SecondaryActionButton(
          key: AppKeys.mobileStopAssistanceButton,
          label: 'Stop Assistance',
          icon: AppIcons.stop,
          semanticLabel: canStop
              ? 'Stop camera and object detection'
              : 'Assistance is not running',
          onPressed: canStop
              ? () => ref
                    .read(assistanceControllerProvider.notifier)
                    .stopAssistance()
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),

        // Retry button (only in error or permissionRequired states)
        if (assistState == MobileAssistanceState.error ||
            assistState == MobileAssistanceState.permissionRequired)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: SecondaryActionButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              semanticLabel: 'Retry starting assistance',
              onPressed: () =>
                  ref.read(assistanceControllerProvider.notifier).retry(),
            ),
          ),

        if (permissionStatus.isPermanentlyDenied)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: PrimaryActionButton(
              label: 'Open Settings',
              icon: AppIcons.settings,
              semanticLabel: 'Open Android settings to grant camera permission',
              onPressed: () => ref
                  .read(cameraPermissionControllerProvider.notifier)
                  .openSettings(),
            ),
          ),

        // Permission details
        SecondaryActionButton(
          key: AppKeys.mobilePermissionButton,
          label: 'Permission Details',
          icon: AppIcons.camera,
          semanticLabel: AppStrings.openPermissions,
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoute.permissions.path),
        ),
        const SizedBox(height: AppSpacing.space5),

        const SafetyNotice(
          title: 'Assistive aid limitation',
          messages: [AppStrings.safetyAid, AppStrings.safetyAccuracy],
        ),
      ],
    );
  }

  Widget _buildStatusPill(
    MobileAssistanceState assistState,
    AssistanceFailureKind? failureKind,
    CameraPermissionStatus permissionStatus,
  ) {
    final (label, icon, color) = switch (assistState) {
      MobileAssistanceState.active => (
        'Detecting',
        AppIcons.play,
        AppColors.success,
      ),
      MobileAssistanceState.paused => (
        'Paused',
        AppIcons.stopCircle,
        AppColors.warning,
      ),
      MobileAssistanceState.starting ||
      MobileAssistanceState.initialisingCamera ||
      MobileAssistanceState.loadingModel => (
        'Starting...',
        AppIcons.refresh,
        AppColors.warning,
      ),
      MobileAssistanceState.stopping => (
        'Stopping...',
        AppIcons.refresh,
        AppColors.warning,
      ),
      MobileAssistanceState.error => (
        failureKind?.label ?? 'Assistance error',
        AppIcons.warning,
        AppColors.error,
      ),
      MobileAssistanceState.permissionRequired => (
        permissionStatus.isPermanentlyDenied
            ? 'Permission permanently denied'
            : permissionStatus == CameraPermissionStatus.denied
            ? 'Permission denied'
            : 'Camera permission required',
        AppIcons.warning,
        AppColors.error,
      ),
      MobileAssistanceState.ready => (
        'Ready',
        AppIcons.play,
        AppColors.success,
      ),
      _ => ('Inactive', AppIcons.stopCircle, AppColors.warning),
    };

    return StatusPill(label: label, icon: icon, color: color);
  }

  String _getStatusDescription(
    MobileAssistanceState assistState,
    bool hasPermission,
  ) {
    return switch (assistState) {
      MobileAssistanceState.active =>
        'Detecting obstacles and providing feedback.',
      MobileAssistanceState.paused => 'Assistance paused. Tap Start to resume.',
      MobileAssistanceState.starting => 'Starting assistance...',
      MobileAssistanceState.initialisingCamera => 'Initialising camera...',
      MobileAssistanceState.loadingModel => 'Loading detection model...',
      MobileAssistanceState.stopping => 'Stopping assistance...',
      MobileAssistanceState.ready => 'Ready. Tap Start Assistance to begin.',
      MobileAssistanceState.error => 'An error occurred. See details below.',
      MobileAssistanceState.permissionRequired =>
        'Camera permission is required to start.',
      MobileAssistanceState.idle =>
        hasPermission
            ? 'Tap Start Assistance to begin detecting obstacles.'
            : 'Camera permission is required before starting assistance.',
    };
  }

  String _getStartButtonLabel(
    MobileAssistanceState assistState,
    bool isActive,
    bool isBusy,
  ) {
    if (isActive) return 'Assistance Running';
    if (isBusy) return assistState.label;
    if (assistState == MobileAssistanceState.paused) return 'Resume Assistance';
    return 'Start Assistance';
  }

  String _getStartButtonSemantic(
    MobileAssistanceState assistState,
    bool hasPermission,
    bool isActive,
    bool isBusy,
  ) {
    if (!hasPermission) {
      return 'Request camera permission and start object detection';
    }
    if (isActive) return 'Assistance is already running';
    if (isBusy) return '${assistState.label}. Please wait.';
    if (assistState == MobileAssistanceState.paused) {
      return 'Resume object detection';
    }
    return 'Start camera and object detection';
  }
}

class _AssistanceStatusGrid extends StatelessWidget {
  const _AssistanceStatusGrid({
    required this.assistState,
    required this.hasPermission,
    required this.detectionCount,
    required this.alertCount,
    required this.feedbackActive,
    required this.feedbackMode,
  });

  final MobileAssistanceState assistState;
  final bool hasPermission;
  final int detectionCount;
  final int alertCount;
  final bool feedbackActive;
  final String feedbackMode;

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
            StatusSummaryCard(
              label: 'Status',
              value: assistState.label,
              icon: assistState.isActive ? AppIcons.play : AppIcons.stopCircle,
              color: assistState.isActive
                  ? AppColors.success
                  : (assistState == MobileAssistanceState.error
                        ? AppColors.error
                        : AppColors.warning),
            ),
            StatusSummaryCard(
              label: 'Detection',
              value: assistState.isActive
                  ? '$detectionCount objects'
                  : 'Not running',
              icon: AppIcons.visibility,
              color: detectionCount > 0 ? AppColors.success : AppColors.warning,
            ),
            StatusSummaryCard(
              label: 'Alerts',
              value: feedbackActive ? '$alertCount active' : 'Not running',
              icon: AppIcons.warning,
              color: alertCount > 0 ? AppColors.success : AppColors.warning,
            ),
            StatusSummaryCard(
              label: 'Feedback',
              value: feedbackActive ? feedbackMode : 'Inactive',
              icon: AppIcons.play,
              color: feedbackActive ? AppColors.success : AppColors.warning,
            ),
          ].map((child) => SizedBox(width: width, child: child)).toList(),
        );
      },
    );
  }
}
