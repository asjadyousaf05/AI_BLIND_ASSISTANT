import 'dart:typed_data';

/// The positioning guidance cue produced for a blind user.
enum FramingCue {
  aligned,
  moveHigher,
  moveLower,
  moveLeft,
  moveRight,
  tooDark,
  tooBright,
  noDocument;

  String get spokenGuidance => switch (this) {
    FramingCue.aligned => 'Document aligned.',
    FramingCue.moveHigher => 'Move phone higher.',
    FramingCue.moveLower => 'Move phone lower.',
    FramingCue.moveLeft => 'Move phone left.',
    FramingCue.moveRight => 'Move phone right.',
    FramingCue.tooDark => 'Too dark.',
    FramingCue.tooBright => 'Too bright.',
    FramingCue.noDocument => 'Point at document.',
  };
}

/// Lightweight on-device document positioning and framing analyzer.
///
/// Analyzes image luminance and contrast distribution across a 3x3 quadrant grid
/// to provide real-time spatial guidance so blind users can frame documents
/// independently without visual sight.
class DocumentFramingAnalyzer {
  const DocumentFramingAnalyzer();

  /// Analyzes the Y (luminance) plane of a camera frame.
  FramingCue analyzeYPlane(
    Uint8List yBytes, {
    required int width,
    required int height,
  }) {
    if (yBytes.isEmpty || width <= 0 || height <= 0) {
      return FramingCue.noDocument;
    }

    // 1. Overall luminance check
    int sumLuminance = 0;
    int sampleCount = 0;
    final step = (yBytes.length ~/ 200).clamp(1, 400);
    for (int i = 0; i < yBytes.length; i += step) {
      sumLuminance += yBytes[i];
      sampleCount++;
    }
    final avgLuminance = sampleCount > 0 ? sumLuminance / sampleCount : 128.0;

    if (avgLuminance < 25) return FramingCue.tooDark;
    if (avgLuminance > 235) return FramingCue.tooBright;

    // 2. 3x3 Quadrant contrast energy analysis
    // Grid:
    // [0,0] Top-Left   [0,1] Top-Center   [0,2] Top-Right
    // [1,0] Mid-Left   [1,1] Mid-Center   [1,2] Mid-Right
    // [2,0] Bot-Left   [2,1] Bot-Center   [2,2] Bot-Right
    final rowEnergy = List<double>.filled(3, 0.0);
    final colEnergy = List<double>.filled(3, 0.0);
    final rowCounts = List<int>.filled(3, 0);
    final colCounts = List<int>.filled(3, 0);

    final rowHeight = height / 3.0;
    final colWidth = width / 3.0;

    // Sample across grid rows and columns
    final sampleStepY = (height ~/ 15).clamp(1, 50);
    final sampleStepX = (width ~/ 15).clamp(1, 50);

    for (int y = sampleStepY; y < height - sampleStepY; y += sampleStepY) {
      final rowIndex = (y / rowHeight).floor().clamp(0, 2);
      final rowOffset = y * width;

      for (int x = sampleStepX; x < width - sampleStepX; x += sampleStepX) {
        final colIndex = (x / colWidth).floor().clamp(0, 2);
        final pixelIndex = rowOffset + x;

        if (pixelIndex + 1 < yBytes.length &&
            pixelIndex + width < yBytes.length) {
          // Horizontal and vertical gradients (edges / text characters)
          final gradX = (yBytes[pixelIndex + 1] - yBytes[pixelIndex]).abs();
          final gradY = (yBytes[pixelIndex + width] - yBytes[pixelIndex]).abs();
          final contrast = gradX + gradY;

          if (contrast > 15) {
            rowEnergy[rowIndex] += contrast;
            colEnergy[colIndex] += contrast;
          }
          rowCounts[rowIndex]++;
          colCounts[colIndex]++;
        }
      }
    }

    final totalRowEnergy = rowEnergy.reduce((a, b) => a + b);
    final totalColEnergy = colEnergy.reduce((a, b) => a + b);

    if (totalRowEnergy < 80) {
      return FramingCue.noDocument;
    }

    // 3. Directional skew analysis
    final topRatio = rowEnergy[0] / totalRowEnergy;
    final botRatio = rowEnergy[2] / totalRowEnergy;
    final leftRatio = colEnergy[0] / totalColEnergy;
    final rightRatio = colEnergy[2] / totalColEnergy;

    if (botRatio > 0.60 && topRatio < 0.20) {
      return FramingCue.moveHigher;
    }
    if (topRatio > 0.60 && botRatio < 0.20) {
      return FramingCue.moveLower;
    }
    if (leftRatio > 0.60 && rightRatio < 0.20) {
      return FramingCue.moveRight;
    }
    if (rightRatio > 0.60 && leftRatio < 0.20) {
      return FramingCue.moveLeft;
    }

    // Document is centered and contrast is well balanced
    return FramingCue.aligned;
  }
}
