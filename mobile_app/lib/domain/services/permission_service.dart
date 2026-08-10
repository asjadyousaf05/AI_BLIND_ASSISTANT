import '../enums/camera_permission_status.dart';

abstract interface class PermissionService {
  Future<CameraPermissionStatus> checkCameraPermission();

  Future<CameraPermissionStatus> requestCameraPermission();

  Future<bool> openAppSettings();
}
