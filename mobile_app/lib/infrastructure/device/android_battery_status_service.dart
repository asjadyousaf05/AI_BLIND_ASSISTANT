import 'package:flutter/services.dart';

import '../../domain/services/battery_status_service.dart';

class AndroidBatteryStatusService implements BatteryStatusService {
  const AndroidBatteryStatusService();

  static const channel = MethodChannel('ai_blind_assistant/device_status');

  @override
  Future<int?> readPercentage() async {
    try {
      final value = await channel.invokeMethod<int>('batteryPercentage');
      return value != null && value >= 0 && value <= 100 ? value : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
