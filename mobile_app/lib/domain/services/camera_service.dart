import 'dart:typed_data';

import '../enums/camera_state.dart';

/// Represents a single camera frame for processing.
class CameraFrame {
  const CameraFrame({
    required this.planes,
    required this.width,
    required this.height,
    required this.timestamp,
    required this.rotationDegrees,
    required this.isFrontFacing,
    this.format = CameraFrameFormat.yuv420,
  });

  /// Y, U and V planes in Android YUV_420_888 order.
  ///
  /// Row and pixel strides are retained because concatenated YUV_420_888
  /// planes are not equivalent to packed NV21.
  final List<CameraPlane> planes;
  final int width;
  final int height;
  final DateTime timestamp;

  /// Clockwise rotation needed to make the sensor frame upright for preview.
  final int rotationDegrees;
  final bool isFrontFacing;
  final CameraFrameFormat format;
}

class CameraPlane {
  const CameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

enum CameraFrameFormat { yuv420, bgra8888, nv21 }

/// Callback for frame delivery.
typedef FrameCallback = void Function(CameraFrame frame);

/// Abstract camera service interface for testability.
abstract interface class CameraService {
  CameraState get currentState;

  Stream<CameraState> get stateStream;

  Future<void> initialize();

  Future<void> startPreview();

  Future<void> stopPreview();

  /// Releases camera hardware while keeping this service reusable.
  Future<void> release();

  /// Permanently closes service-owned streams and resources.
  Future<void> dispose();

  void setFrameCallback(FrameCallback? callback);

  /// Returns a widget for the camera preview, or null if unavailable.
  Object? get previewWidget;

  String? get lastError;
  Future<void> setTorch(bool enabled);
  bool get isTorchOn;
}
