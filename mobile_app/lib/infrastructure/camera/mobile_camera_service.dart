import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/services.dart';

import '../../domain/enums/camera_state.dart';
import '../../domain/services/camera_service.dart';

class MobileCameraService implements CameraService {
  cam.CameraController? _controller;
  void Function()? _controllerListener;
  final _stateController = StreamController<CameraState>.broadcast();
  CameraState _currentState = CameraState.uninitialized;
  FrameCallback? _frameCallback;
  DateTime _lastFrameTime = DateTime(2000);
  bool _disposed = false;
  String? _lastError;
  Future<void>? _initialization;
  int _generation = 0;

  /// Minimum milliseconds between delivered frames. Throttles delivery so
  /// the detector does not process every raw camera frame.
  static const _frameIntervalMs = 200;

  @override
  CameraState get currentState => _currentState;

  @override
  String? get lastError => _lastError;

  @override
  Stream<CameraState> get stateStream => _stateController.stream;

  @override
  Object? get previewWidget {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return null;
    return ctrl;
  }

  void _setState(CameraState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    if (_currentState == CameraState.ready) return;
    if (_currentState == CameraState.loading ||
        _currentState == CameraState.previewing) {
      await _initialization;
      return;
    }

    final generation = ++_generation;
    _initialization = _initializeCamera(generation);
    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initializeCamera(int generation) async {
    _lastError = null;
    _setState(CameraState.loading);

    try {
      final cameras = await cam.availableCameras();
      if (cameras.isEmpty) {
        _setState(CameraState.unavailable);
        return;
      }

      final rearCameras = cameras
          .where(
            (camera) => camera.lensDirection == cam.CameraLensDirection.back,
          )
          .toList(growable: false);
      if (rearCameras.isEmpty) {
        _lastError = 'No rear camera was reported by Android.';
        _setState(CameraState.unavailable);
        return;
      }

      final failures = <String>[];
      for (final description in rearCameras) {
        if (_disposed || generation != _generation) return;

        final controller = cam.CameraController(
          description,
          cam.ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: cam.ImageFormatGroup.yuv420,
        );
        try {
          await controller.initialize();

          if (_disposed || generation != _generation) {
            await controller.dispose();
            return;
          }

          _controller = controller;
          _controllerListener = () => _handleControllerUpdate(controller);
          controller.addListener(_controllerListener!);
          _setState(CameraState.ready);
          return;
        } catch (error) {
          failures.add(
            describeCameraFailure(
              error,
              operation: 'Rear camera ${description.name}',
            ),
          );
          try {
            await controller.dispose();
          } catch (disposeError) {
            failures.add(
              describeCameraFailure(disposeError, operation: 'Camera cleanup'),
            );
          }
        }
      }

      _lastError = 'Camera initialization failed. ${failures.join(' | ')}';
      _setState(CameraState.error);
    } catch (error) {
      _lastError = describeCameraFailure(error, operation: 'Camera discovery');
      _setState(CameraState.error);
    }
  }

  @override
  Future<void> startPreview() async {
    if (_disposed) return;
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (_currentState == CameraState.previewing) return;

    try {
      await ctrl.startImageStream(_handleImageStream);
      _setState(CameraState.previewing);
    } catch (error) {
      _lastError = describeCameraFailure(
        error,
        operation: 'Camera stream start',
      );
      _setState(CameraState.error);
    }
  }

  @override
  Future<void> stopPreview() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    _setState(CameraState.stopping);

    try {
      if (ctrl.value.isStreamingImages) {
        await ctrl.stopImageStream();
      }
      _setState(CameraState.ready);
    } catch (error) {
      _lastError = describeCameraFailure(
        error,
        operation: 'Camera stream stop',
      );
      _setState(CameraState.error);
    }
  }

  @override
  Future<void> release() async {
    _generation++;
    _frameCallback = null;

    try {
      final initialization = _initialization;
      if (initialization != null) {
        await initialization;
      }
      final ctrl = _controller;
      if (ctrl != null) {
        final listener = _controllerListener;
        if (listener != null) {
          ctrl.removeListener(listener);
        }
        if (ctrl.value.isStreamingImages) {
          await ctrl.stopImageStream();
        }
        await ctrl.dispose();
      }
    } catch (error) {
      _lastError = describeCameraFailure(
        error,
        operation: 'Camera resource release',
      );
      _setState(CameraState.error);
      rethrow;
    }

    _controller = null;
    _controllerListener = null;
    if (!_disposed) {
      _setState(CameraState.uninitialized);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await release();
    _disposed = true;
    await _stateController.close();
  }

  @override
  void setFrameCallback(FrameCallback? callback) {
    _frameCallback = callback;
  }

  void _handleImageStream(cam.CameraImage image) {
    if (_frameCallback == null) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameIntervalMs) {
      return;
    }
    _lastFrameTime = now;

    final controller = _controller;
    if (controller == null) return;

    final planes = image.planes
        .map(
          (plane) => CameraPlane(
            // Camera plugins may reuse plane memory after this callback.
            bytes: Uint8List.fromList(plane.bytes),
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel ?? 1,
          ),
        )
        .toList(growable: false);
    final frame = CameraFrame(
      planes: planes,
      width: image.width,
      height: image.height,
      timestamp: now,
      rotationDegrees: _rotationDegrees(controller),
      isFrontFacing:
          controller.description.lensDirection == cam.CameraLensDirection.front,
      format: CameraFrameFormat.yuv420,
    );

    _frameCallback!(frame);
  }

  void _handleControllerUpdate(cam.CameraController controller) {
    if (_disposed || !identical(_controller, controller)) return;
    if (!controller.value.hasError) return;

    final detail = controller.value.errorDescription?.trim();
    _lastError = detail == null || detail.isEmpty
        ? 'Android reported a camera runtime error.'
        : 'Android camera runtime error: ${_sanitizeCameraDetail(detail)}';
    _setState(CameraState.error);
  }

  int _rotationDegrees(cam.CameraController controller) {
    final deviceDegrees = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensor = controller.description.sensorOrientation;
    if (controller.description.lensDirection == cam.CameraLensDirection.front) {
      return (sensor + deviceDegrees) % 360;
    }
    return (sensor - deviceDegrees + 360) % 360;
  }
}

/// Produces an actionable, bounded message without exposing frame data.
String describeCameraFailure(Object error, {required String operation}) {
  if (error is cam.CameraException) {
    final detail = error.description?.trim();
    final suffix = detail == null || detail.isEmpty
        ? ''
        : ': ${_sanitizeCameraDetail(detail)}';
    return '$operation [${error.code}]$suffix';
  }
  if (error is PlatformException) {
    final detail = error.message?.trim();
    final suffix = detail == null || detail.isEmpty
        ? ''
        : ': ${_sanitizeCameraDetail(detail)}';
    return '$operation [${error.code}]$suffix';
  }
  return '$operation failed (${error.runtimeType})';
}

String _sanitizeCameraDetail(String detail) {
  final singleLine = detail.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  const maximumLength = 180;
  return singleLine.length <= maximumLength
      ? singleLine
      : '${singleLine.substring(0, maximumLength)}…';
}
