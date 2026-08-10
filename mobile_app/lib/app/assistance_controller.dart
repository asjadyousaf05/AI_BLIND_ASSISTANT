import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_observer.dart';
import '../domain/enums/assistance_failure_kind.dart';
import '../domain/enums/camera_state.dart';
import '../domain/enums/inference_state.dart';
import '../domain/enums/mobile_assistance_state.dart';
import 'camera_providers.dart';
import 'detection_providers.dart';
import 'feedback_providers.dart';
import 'inference_providers.dart';
import 'permission_providers.dart';

/// Diagnostic metrics for the assistance session.
class AssistanceDiagnostics {
  const AssistanceDiagnostics({
    required this.processedFrames,
    required this.droppedFrames,
    required this.totalInferenceMs,
  });

  final int processedFrames;
  final int droppedFrames;
  final int totalInferenceMs;

  int get averageInferenceMs =>
      processedFrames > 0 ? totalInferenceMs ~/ processedFrames : 0;
}

/// Holds the unified session state plus optional error context.
class AssistanceSessionState {
  const AssistanceSessionState({
    required this.state,
    this.errorMessage,
    this.failureKind,
  });

  final MobileAssistanceState state;
  final String? errorMessage;
  final AssistanceFailureKind? failureKind;

  AssistanceSessionState copyWith({
    MobileAssistanceState? state,
    String? errorMessage,
    AssistanceFailureKind? failureKind,
  }) {
    return AssistanceSessionState(
      state: state ?? this.state,
      errorMessage: errorMessage,
      failureKind: failureKind,
    );
  }
}

final assistanceControllerProvider =
    NotifierProvider<AssistanceController, AssistanceSessionState>(
      AssistanceController.new,
    );

class AssistanceController extends Notifier<AssistanceSessionState> {
  AppLifecycleObserver? _lifecycleObserver;
  bool _startInProgress = false;
  bool _stopInProgress = false;
  int _sessionGeneration = 0;
  AssistanceDiagnostics get diagnostics {
    final inference = ref.read(inferenceControllerProvider.notifier);
    return AssistanceDiagnostics(
      processedFrames: inference.processedFrames,
      droppedFrames: inference.droppedFrames,
      totalInferenceMs: inference.totalInferenceMs,
    );
  }

  @override
  AssistanceSessionState build() {
    ref.onDispose(_cleanup);
    _setupLifecycleObserver();
    ref.listen(inferenceControllerProvider, (previous, next) {
      if (next == InferenceState.error &&
          state.state == MobileAssistanceState.active) {
        unawaited(_handleRuntimeInferenceFailure());
      }
    });
    ref.listen(cameraControllerProvider, (previous, next) {
      if (next == CameraState.error &&
          previous != CameraState.error &&
          state.state == MobileAssistanceState.active) {
        unawaited(_handleRuntimeCameraFailure());
      }
    });
    ref.listen(feedbackControllerProvider, (previous, next) {
      final feedbackError = ref
          .read(feedbackControllerProvider.notifier)
          .lastError;
      if (previous == true &&
          !next &&
          feedbackError != null &&
          state.state == MobileAssistanceState.active) {
        unawaited(_handleRuntimeFeedbackFailure(feedbackError));
      }
    });
    return const AssistanceSessionState(state: MobileAssistanceState.idle);
  }

  MobileAssistanceState get currentState => state.state;

  bool get requiresDetachCleanup => switch (state.state) {
    MobileAssistanceState.starting ||
    MobileAssistanceState.initialisingCamera ||
    MobileAssistanceState.loadingModel ||
    MobileAssistanceState.ready ||
    MobileAssistanceState.active ||
    MobileAssistanceState.paused => true,
    MobileAssistanceState.idle ||
    MobileAssistanceState.permissionRequired ||
    MobileAssistanceState.stopping ||
    MobileAssistanceState.error => false,
  };

  /// Starts the full Mobile Mode assistance pipeline.
  Future<void> startAssistance() async {
    if (_startInProgress || _stopInProgress) return;
    if (!state.state.canStart) return;

    _startInProgress = true;
    final generation = ++_sessionGeneration;
    try {
      // 1. Check permission
      _setState(MobileAssistanceState.starting);
      final permController = ref.read(
        cameraPermissionControllerProvider.notifier,
      );
      await permController.checkPermission();
      if (!_isCurrent(generation)) return;
      var permStatus = ref.read(cameraPermissionControllerProvider);

      if (!permStatus.isGranted) {
        permStatus = await permController.requestPermission();
        if (!_isCurrent(generation)) return;
      }

      if (permStatus.isPermanentlyDenied) {
        await _failStartup(
          'Camera permission permanently denied. Open device settings to grant access.',
          AssistanceFailureKind.permissionPermanentlyDenied,
        );
        return;
      }
      if (!permStatus.isGranted) {
        state = const AssistanceSessionState(
          state: MobileAssistanceState.permissionRequired,
          errorMessage: 'Camera permission was denied.',
          failureKind: AssistanceFailureKind.permissionDenied,
        );
        return;
      }

      // 2. Initialise camera
      _setState(MobileAssistanceState.initialisingCamera);
      final cameraCtrl = ref.read(cameraControllerProvider.notifier);
      await cameraCtrl.initializeCamera();
      if (!_isCurrent(generation)) return;

      final cameraState = ref.read(cameraControllerProvider);
      if (cameraState == CameraState.unavailable) {
        await _failStartup(
          'No rear camera available on this device.',
          AssistanceFailureKind.camera,
        );
        return;
      }
      if (cameraState == CameraState.error) {
        await _failStartup(
          'Camera failed to initialise. '
          '${cameraCtrl.lastError ?? 'Try again or restart the app.'}',
          AssistanceFailureKind.camera,
        );
        return;
      }

      // 3. Load model
      _setState(MobileAssistanceState.loadingModel);
      final inferenceCtrl = ref.read(inferenceControllerProvider.notifier);
      await inferenceCtrl.loadModel();
      if (!_isCurrent(generation)) return;

      final inferenceState = ref.read(inferenceControllerProvider);
      if (inferenceState == InferenceState.error) {
        await _failStartup(
          'Detection model failed to load. '
          '${inferenceCtrl.lastError ?? 'Verify the bundled model asset.'}',
          AssistanceFailureKind.model,
        );
        return;
      }

      _setState(MobileAssistanceState.ready);

      // 4. Start camera preview and frame processing
      await cameraCtrl.startPreview();
      if (!_isCurrent(generation)) return;

      final postCameraState = ref.read(cameraControllerProvider);
      if (postCameraState != CameraState.previewing) {
        await _failStartup(
          'Camera stream could not start. '
          '${cameraCtrl.lastError ?? 'Try again.'}',
          AssistanceFailureKind.camera,
        );
        return;
      }

      // 5. Start inference pipeline
      inferenceCtrl.startProcessingFrames();

      // 6. Start feedback engine
      final feedbackCtrl = ref.read(feedbackControllerProvider.notifier);
      feedbackCtrl.updateSettings();
      try {
        await feedbackCtrl.start();
      } catch (error) {
        if (_isCurrent(generation)) {
          await _failStartup(
            'Accessible feedback failed to initialize. '
            '${_safeErrorMessage(error)}',
            AssistanceFailureKind.feedback,
          );
        }
        return;
      }
      if (!_isCurrent(generation)) return;

      // 7. Transition to active
      _setState(MobileAssistanceState.active);
      _announceState('Mobile assistance started');
    } catch (e) {
      if (_isCurrent(generation)) {
        await _failStartup(
          'Unexpected error during startup: ${_safeErrorMessage(e)}',
          AssistanceFailureKind.unexpected,
        );
      }
    } finally {
      _startInProgress = false;
    }
  }

  /// Stops the assistance session completely. Idempotent.
  Future<void> stopAssistance() async {
    if (_stopInProgress) return;
    if (state.state == MobileAssistanceState.idle ||
        state.state == MobileAssistanceState.stopping) {
      return;
    }

    _stopInProgress = true;
    _sessionGeneration++;

    try {
      _setState(MobileAssistanceState.stopping);
      final cleanupErrors = await _releasePipelineResources();
      if (cleanupErrors.isEmpty) {
        _setState(MobileAssistanceState.idle);
        _announceState('Mobile assistance stopped');
      } else {
        _setError(
          'Assistance stopped, but resource cleanup failed: '
          '${cleanupErrors.join('; ')}',
          AssistanceFailureKind.unexpected,
        );
        _announceState('Assistance stopped with a cleanup error.');
      }
    } catch (error) {
      _setError(
        'Assistance stopped with an error: ${_safeErrorMessage(error)}',
        AssistanceFailureKind.unexpected,
      );
    } finally {
      _stopInProgress = false;
    }
  }

  /// Pauses the pipeline for lifecycle events and releases native resources.
  Future<void> pauseAssistance() async {
    if (state.state != MobileAssistanceState.active) return;

    _sessionGeneration++;
    final cleanupErrors = await _releasePipelineResources();
    if (cleanupErrors.isEmpty) {
      _setState(MobileAssistanceState.paused);
    } else {
      _setError(
        'Assistance paused, but resource cleanup failed: '
        '${cleanupErrors.join('; ')}',
        AssistanceFailureKind.unexpected,
      );
    }
  }

  /// Resumes after a lifecycle pause without restarting camera capture.
  Future<void> handleResume() async {
    if (state.state != MobileAssistanceState.paused) return;

    // Re-check permission in case it was revoked
    final permController = ref.read(
      cameraPermissionControllerProvider.notifier,
    );
    await permController.checkPermission();
    final permStatus = ref.read(cameraPermissionControllerProvider);

    if (!permStatus.isGranted) {
      _setState(MobileAssistanceState.permissionRequired);
      _announceState(
        'Camera permission was removed. Grant permission to resume.',
      );
      return;
    }

    // Don't auto-restart for safety — user must tap Start again.
    _setState(MobileAssistanceState.paused);
    _announceState('Assistance paused. Tap Start to resume.');
  }

  /// Handles complete detach — full resource cleanup.
  Future<void> handleDetach() async {
    // Application-scope disposal also disposes the camera, inference, and TTS
    // service providers directly. Do not touch provider state after that point.
    if (!ref.mounted) return;
    await stopAssistance();
  }

  /// Retry from error state.
  Future<void> retry() async {
    if (state.state == MobileAssistanceState.error ||
        state.state == MobileAssistanceState.permissionRequired) {
      _setState(MobileAssistanceState.idle);
      await startAssistance();
    }
  }

  void _setState(MobileAssistanceState newState) {
    state = AssistanceSessionState(state: newState);
  }

  void _setError(String message, AssistanceFailureKind kind) {
    state = AssistanceSessionState(
      state: MobileAssistanceState.error,
      errorMessage: message,
      failureKind: kind,
    );
  }

  Future<void> _failStartup(String message, AssistanceFailureKind kind) async {
    final cleanupErrors = await _releasePipelineResources();
    final suffix = cleanupErrors.isEmpty
        ? ''
        : ' Cleanup also failed: ${cleanupErrors.join('; ')}';
    _setError('$message$suffix', kind);
  }

  Future<void> _handleRuntimeInferenceFailure() async {
    final cleanupErrors = await _releasePipelineResources();
    final suffix = cleanupErrors.isEmpty
        ? ''
        : ' Cleanup also failed: ${cleanupErrors.join('; ')}';
    _setError(
      'Object detection stopped because on-device inference failed. Try again.'
      '$suffix',
      AssistanceFailureKind.inference,
    );
    _announceState('Detection error. Assistance stopped.');
  }

  Future<void> _handleRuntimeCameraFailure() async {
    final camera = ref.read(cameraControllerProvider.notifier);
    final detail = camera.lastError;
    final cleanupErrors = await _releasePipelineResources();
    final cleanupSuffix = cleanupErrors.isEmpty
        ? ''
        : ' Cleanup also failed: ${cleanupErrors.join('; ')}';
    final detailSuffix = detail == null ? '' : ' ${_safeErrorMessage(detail)}';
    _setError(
      'Camera stopped unexpectedly.$detailSuffix$cleanupSuffix',
      AssistanceFailureKind.camera,
    );
    _announceState('Camera error. Assistance stopped.');
  }

  Future<void> _handleRuntimeFeedbackFailure(String detail) async {
    final cleanupErrors = await _releasePipelineResources();
    final suffix = cleanupErrors.isEmpty
        ? ''
        : ' Cleanup also failed: ${cleanupErrors.join('; ')}';
    _setError(
      'Accessible feedback stopped: ${_safeErrorMessage(detail)}$suffix',
      AssistanceFailureKind.feedback,
    );
    _announceState('Feedback error. Assistance stopped.');
  }

  Future<List<String>> _releasePipelineResources() async {
    final errors = <String>[];
    try {
      await ref.read(feedbackControllerProvider.notifier).stop();
    } catch (error) {
      errors.add('feedback: ${_safeErrorMessage(error)}');
    }
    try {
      await ref.read(inferenceControllerProvider.notifier).unloadModel();
    } catch (error) {
      errors.add('model: ${_safeErrorMessage(error)}');
    }
    try {
      final camera = ref.read(cameraControllerProvider.notifier);
      await camera.stopPreview();
      await camera.releaseCamera();
    } catch (error) {
      errors.add('camera: ${_safeErrorMessage(error)}');
    }
    try {
      ref.read(detectionResultsProvider.notifier).clear();
    } catch (error) {
      errors.add('detections: ${_safeErrorMessage(error)}');
    }
    return errors;
  }

  void _announceState(String message) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    }
  }

  String _safeErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.length > 80) return msg.substring(0, 80);
    return msg;
  }

  bool _isCurrent(int generation) => generation == _sessionGeneration;

  void _setupLifecycleObserver() {
    _lifecycleObserver = AppLifecycleObserver(onStateChanged: _handleLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void _handleLifecycle(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (state.state == MobileAssistanceState.active) {
          pauseAssistance();
        }
      case AppLifecycleState.resumed:
        if (state.state == MobileAssistanceState.paused) {
          handleResume();
        }
      case AppLifecycleState.detached:
        handleDetach();
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _cleanup() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}
