import 'package:vibration/vibration.dart';

import '../../domain/enums/risk_level.dart';
import '../../domain/services/vibration_service.dart';

class DeviceVibrationService implements VibrationService {
  bool _available = false;
  bool _checked = false;

  @override
  bool get isAvailable => _available;

  Future<void> _ensureChecked() async {
    if (_checked) return;
    _available = await Vibration.hasVibrator();
    _checked = true;
  }

  @override
  Future<void> vibrateForRisk(RiskLevel level) async {
    await _ensureChecked();
    if (!_available) {
      throw StateError('Vibration is unavailable on this device');
    }

    switch (level) {
      case RiskLevel.critical:
        // Three strong pulses
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200, 100, 200],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      case RiskLevel.high:
        // Two strong pulses
        await Vibration.vibrate(
          pattern: [0, 150, 100, 150],
          intensities: [0, 200, 0, 200],
        );
      case RiskLevel.moderate:
        // One medium pulse
        await Vibration.vibrate(duration: 100, amplitude: 128);
      case RiskLevel.low:
        // One light pulse
        await Vibration.vibrate(duration: 50, amplitude: 64);
    }
  }

  @override
  Future<void> cancel() async {
    await _ensureChecked();
    if (!_available) return;
    await Vibration.cancel();
  }
}
