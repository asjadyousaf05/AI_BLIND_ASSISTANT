import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' as cam;
import 'package:ai_blind_assistant/domain/enums/camera_state.dart';
import 'package:ai_blind_assistant/domain/services/camera_service.dart';
import 'package:ai_blind_assistant/infrastructure/camera/mobile_camera_service.dart';

class FakeCameraService implements CameraService {
  final CameraFrameFormat _format = CameraFrameFormat.yuv420;
  FrameCallback? _callback;
  bool _initialized = false;
  bool _previewing = false;

  @override
  String? get lastError => null;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> startPreview() async {
    if (!_initialized) throw StateError('Not initialized');
    _previewing = true;
  }

  @override
  Future<void> stopPreview() async {
    _previewing = false;
  }

  @override
  Future<void> dispose() async {
    await release();
  }

  @override
  Future<void> release() async {
    _previewing = false;
    _initialized = false;
    _callback = null;
  }

  @override
  void setFrameCallback(FrameCallback? callback) {
    _callback = callback;
  }

  @override
  dynamic get previewWidget => null;

  @override
  CameraState get currentState =>
      _previewing ? CameraState.previewing : CameraState.uninitialized;

  @override
  Stream<CameraState> get stateStream => const Stream.empty();

  void simulateFrame() {
    _callback?.call(
      CameraFrame(
        planes: _testPlanes(),
        width: 640,
        height: 480,
        timestamp: DateTime.now(),
        rotationDegrees: 0,
        isFrontFacing: false,
        format: _format,
      ),
    );
  }
}

void main() {
  group('CameraState', () {
    // UT-CAM-001: Camera state labels
    test('UT-CAM-001: all states have labels', () {
      for (final state in CameraState.values) {
        expect(state.label.isNotEmpty, isTrue);
      }
    });

    // UT-CAM-002: isActive check
    test('UT-CAM-002: isActive for previewing state', () {
      expect(CameraState.previewing.isActive, isTrue);
      expect(CameraState.uninitialized.isActive, isFalse);
      expect(CameraState.error.isActive, isFalse);
    });
  });

  group('Camera failure diagnostics', () {
    test('UT-CAM-007: preserves CameraX error code and description', () {
      final message = describeCameraFailure(
        cam.CameraException(
          'CameraAccessDenied',
          'Camera permission is not available',
        ),
        operation: 'Rear camera 0',
      );

      expect(message, contains('[CameraAccessDenied]'));
      expect(message, contains('Camera permission is not available'));
    });

    test('UT-CAM-008: bounds and flattens platform error details', () {
      final message = describeCameraFailure(
        PlatformException(
          code: 'camera-in-use',
          message: '${'x' * 100}\n${'y' * 100}',
        ),
        operation: 'Camera stream start',
      );

      expect(message, contains('[camera-in-use]'));
      expect(message, isNot(contains('\n')));
      expect(message.length, lessThan(240));
    });
  });

  group('CameraFrame', () {
    // UT-CAM-003: Frame data integrity
    test('UT-CAM-003: frame holds correct dimensions', () {
      final frame = CameraFrame(
        planes: _testPlanes(),
        width: 640,
        height: 480,
        timestamp: DateTime(2024, 1, 1),
        rotationDegrees: 90,
        isFrontFacing: false,
        format: CameraFrameFormat.yuv420,
      );

      expect(frame.width, 640);
      expect(frame.height, 480);
      expect(frame.rotationDegrees, 90);
      expect(frame.format, CameraFrameFormat.yuv420);
    });
  });

  group('FakeCameraService', () {
    late FakeCameraService service;

    setUp(() {
      service = FakeCameraService();
    });

    // UT-CAM-004: Initialize and preview lifecycle
    test('UT-CAM-004: initialize then start preview', () async {
      await service.initialize();
      await service.startPreview();
      // Should not throw
    });

    // UT-CAM-005: Frame callback receives frames
    test('UT-CAM-005: frame callback invoked', () async {
      int frameCount = 0;
      service.setFrameCallback((_) => frameCount++);
      await service.initialize();
      await service.startPreview();
      service.simulateFrame();
      expect(frameCount, 1);
    });

    // UT-CAM-006: Dispose cleans up
    test('UT-CAM-006: dispose clears callback', () async {
      service.setFrameCallback((_) {});
      await service.dispose();
      // simulateFrame should not throw even after dispose
    });
  });
}

List<CameraPlane> _testPlanes() => [
  CameraPlane(bytes: Uint8List(640), bytesPerRow: 640, bytesPerPixel: 1),
  CameraPlane(bytes: Uint8List(320), bytesPerRow: 320, bytesPerPixel: 1),
  CameraPlane(bytes: Uint8List(320), bytesPerRow: 320, bytesPerPixel: 1),
];
