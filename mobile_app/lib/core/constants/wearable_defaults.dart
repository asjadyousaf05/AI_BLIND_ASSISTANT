abstract final class WearableDefaults {
  /// Default connection target for the Raspberry Pi wearable.
  ///
  /// Uses the Pi's stable mDNS hostname so the app works even when the Pi
  /// receives a different DHCP address. Android NSD resolves `.local` names
  /// on any non-isolated LAN automatically.
  ///
  /// On public/isolated WiFi (where mDNS is blocked) the user should enter
  /// the laptop IP address (e.g. 192.168.x.x) in the host field when the SSH
  /// reverse tunnel is active on the Pi.
  static const host = 'rpi3-ml.local';
  static const port = 8765;
}
