abstract final class WearableDefaults {
  /// Default connection target for the Raspberry Pi wearable.
  ///
  /// Human-readable fallback when bounded NSD discovery finds no service.
  /// The Pi may receive a different DHCP address on each hotspot session;
  /// `.local` resolution must be verified on the actual Android hotspot.
  static const host = 'rpi3-ml.local';
  static const port = 8765;
}
