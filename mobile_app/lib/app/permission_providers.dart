import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_observer.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/safe_debug_logger.dart';
import '../domain/enums/camera_permission_status.dart';
import '../domain/services/permission_service.dart';
import '../infrastructure/device/android_permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return AndroidPermissionService();
});

final cameraPermissionControllerProvider =
    NotifierProvider<CameraPermissionController, CameraPermissionStatus>(
      CameraPermissionController.new,
    );

class CameraPermissionController extends Notifier<CameraPermissionStatus> {
  AppLifecycleObserver? _lifecycleObserver;
  bool _hasRequestedOnce = false;

  @override
  CameraPermissionStatus build() {
    ref.onDispose(_removeLifecycleObserver);
    _setupLifecycleObserver();
    return CameraPermissionStatus.unknown;
  }

  Future<void> checkPermission() async {
    try {
      final service = ref.read(permissionServiceProvider);
      final status = await service.checkCameraPermission();
      state = status;
    } catch (e) {
      _logger.warning('Failed to check camera permission', error: e);
    }
  }

  Future<CameraPermissionStatus> requestPermission() async {
    try {
      final service = ref.read(permissionServiceProvider);
      if (_hasRequestedOnce) {
        final current = await service.checkCameraPermission();
        if (current.isPermanentlyDenied) {
          state = current;
          return current;
        }
      }
      final status = await service.requestCameraPermission();
      _hasRequestedOnce = true;
      state = status;
      return status;
    } catch (e) {
      _logger.warning('Failed to request camera permission', error: e);
      return state;
    }
  }

  Future<bool> openSettings() async {
    try {
      final service = ref.read(permissionServiceProvider);
      return await service.openAppSettings();
    } catch (e) {
      _logger.warning('Failed to open app settings', error: e);
      return false;
    }
  }

  void _setupLifecycleObserver() {
    _lifecycleObserver = AppLifecycleObserver(
      onStateChanged: _handleLifecycleChange,
    );
    final binding = WidgetsBinding.instance;
    binding.addObserver(_lifecycleObserver!);
  }

  void _removeLifecycleObserver() {
    if (_lifecycleObserver != null) {
      final binding = WidgetsBinding.instance;
      binding.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }

  void _handleLifecycleChange(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      checkPermission();
    }
  }

  AppLogger get _logger => const SafeDebugLogger();
}
