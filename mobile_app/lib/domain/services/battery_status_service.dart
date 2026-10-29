/// Reads the current device battery percentage, or null when unavailable.
abstract interface class BatteryStatusService {
  Future<int?> readPercentage();
}
