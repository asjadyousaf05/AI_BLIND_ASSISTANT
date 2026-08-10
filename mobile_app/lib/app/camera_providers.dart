import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_observer.dart';
import '../domain/enums/camera_state.dart';
import '../domain/services/camera_service.dart';
import '../infrastructure/camera/mobile_camera_service.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = MobileCameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

final cameraControllerProvider =
    NotifierProvider<CameraController, CameraState>(CameraController.new);

class CameraController extends Notifier<CameraState> {
  AppLifecycleObserver? _lifecycleObserver;
  StreamSubscription<CameraState>? _stateSub;

  @override
  CameraState build() {
    ref.onDispose(_cleanup);
    _setupLifecycleObserver();
    _listenToService();
    return CameraState.uninitialized;
  }

  CameraService get _service => ref.read(cameraServiceProvider);

  Future<void> initializeCamera() async {
    await _service.initialize();
    // Synchronise immediately as well as through the broadcast stream. Stream
    // delivery is asynchronous, so startup must not inspect a stale state.
    state = _service.currentState;
  }

  Future<void> startPreview() async {
    await _service.startPreview();
    state = _service.currentState;
  }

  Future<void> stopPreview() async {
    await _service.stopPreview();
    state = _service.currentState;
  }

  Future<void> releaseCamera() async {
    await _service.release();
    state = _service.currentState;
  }

  void setFrameCallback(FrameCallback? callback) {
    _service.setFrameCallback(callback);
  }

  Object? get previewWidget => _service.previewWidget;

  String? get lastError => _service.lastError;

  void _listenToService() {
    _stateSub = _service.stateStream.listen((s) {
      state = s;
    });
  }

  void _setupLifecycleObserver() {
    _lifecycleObserver = AppLifecycleObserver(onStateChanged: _handleLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void _handleLifecycle(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if (_service.currentState == CameraState.previewing) {
          _service.stopPreview();
        }
      case AppLifecycleState.resumed:
        // Do NOT auto-resume camera preview here.
        // The AssistanceController owns the lifecycle coordination
        // and will decide whether to restart the pipeline.
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _cleanup() {
    _stateSub?.cancel();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}
