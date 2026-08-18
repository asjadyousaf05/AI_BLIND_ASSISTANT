import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../app/camera_providers.dart';
import '../../../app/detection_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/enums/camera_state.dart';
import '../../../domain/entities/detection_result.dart';

class CameraPreviewWidget extends ConsumerWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraControllerProvider);
    final detections = ref.watch(detectionResultsProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Column(
      children: [
        _buildPreviewArea(context, cameraState, controller, detections),
        const SizedBox(height: AppSpacing.space3),
        _buildStatusAnnouncement(cameraState),
      ],
    );
  }

  Widget _buildPreviewArea(
    BuildContext context,
    CameraState cameraState,
    CameraController controller,
    List<DetectionResult> detections,
  ) {
    final previewAspectRatio = _previewAspectRatio(controller);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: previewAspectRatio,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPreviewContent(cameraState, controller),
              if (cameraState == CameraState.previewing)
                ExcludeSemantics(
                  child: CustomPaint(
                    painter: _DetectionOverlayPainter(detections),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _previewAspectRatio(CameraController controller) {
    final preview = controller.previewWidget;
    if (preview is! cam.CameraController || !preview.value.isInitialized) {
      return 4 / 3;
    }
    final landscape = switch (preview.value.deviceOrientation) {
      DeviceOrientation.landscapeLeft ||
      DeviceOrientation.landscapeRight => true,
      DeviceOrientation.portraitUp || DeviceOrientation.portraitDown => false,
    };
    return landscape
        ? preview.value.aspectRatio
        : 1 / preview.value.aspectRatio;
  }

  Widget _buildPreviewContent(
    CameraState cameraState,
    CameraController controller,
  ) {
    switch (cameraState) {
      case CameraState.previewing:
      case CameraState.ready:
        final preview = controller.previewWidget;
        if (preview is cam.CameraController && preview.value.isInitialized) {
          return cam.CameraPreview(preview);
        }
        return _statusOverlay('Preparing preview...', AppColors.slate400);
      case CameraState.loading:
        return _statusOverlay('Initializing camera...', AppColors.slate400);
      case CameraState.unavailable:
        return _statusOverlay('Camera unavailable', AppColors.error);
      case CameraState.error:
        return _statusOverlay('Camera error', AppColors.error);
      case CameraState.stopping:
        return _statusOverlay('Stopping camera...', AppColors.slate400);
      case CameraState.uninitialized:
        return _statusOverlay('Camera not started', AppColors.slate400);
    }
  }

  Widget _statusOverlay(String message, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: color),
          const SizedBox(height: AppSpacing.space2),
          Text(
            message,
            style: TextStyle(color: color, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAnnouncement(CameraState cameraState) {
    return Semantics(
      liveRegion: true,
      child: Text(
        cameraState.label,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DetectionOverlayPainter extends CustomPainter {
  const _DetectionOverlayPainter(this.detections);

  final List<DetectionResult> detections;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final detection in detections) {
      final box = detection.boundingBox;
      final rect = Rect.fromLTRB(
        box.left * size.width,
        box.top * size.height,
        box.right * size.width,
        box.bottom * size.height,
      );
      canvas.drawRect(rect, boxPaint);

      final text = TextPainter(
        text: TextSpan(
          text: '${detection.label} ${(detection.confidence * 100).round()}%',
          style: const TextStyle(
            color: Colors.black,
            backgroundColor: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      text.paint(
        canvas,
        Offset(rect.left, (rect.top - text.height).clamp(0, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
