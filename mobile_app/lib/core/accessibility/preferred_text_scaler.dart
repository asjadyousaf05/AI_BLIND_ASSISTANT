import 'package:flutter/painting.dart';

/// Adds an app-level readability boost without flattening the platform's
/// nonlinear text-scaling curve.
class PreferredTextScaler extends TextScaler {
  const PreferredTextScaler({
    required this.platformScaler,
    this.multiplier = 1.2,
    this.maxScaleFactor = 2.5,
  }) : assert(multiplier >= 1),
       assert(maxScaleFactor >= multiplier);

  final TextScaler platformScaler;
  final double multiplier;
  final double maxScaleFactor;

  @override
  double scale(double fontSize) {
    assert(fontSize.isFinite && fontSize >= 0);
    if (fontSize == 0) return 0;

    final preferredSize = platformScaler.scale(fontSize) * multiplier;
    return preferredSize.clamp(fontSize, fontSize * maxScaleFactor).toDouble();
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreferredTextScaler &&
          other.platformScaler == platformScaler &&
          other.multiplier == multiplier &&
          other.maxScaleFactor == maxScaleFactor;

  @override
  int get hashCode => Object.hash(platformScaler, multiplier, maxScaleFactor);
}
