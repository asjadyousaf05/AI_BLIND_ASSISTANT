/// Default trusted-LAN endpoint for the owner's current development laptop.
///
/// Direct Wi-Fi IP avoids Android mDNS `.local` lookup failures on standard routers.
/// Automatic fallback hosts allow seamless connection across Wi-Fi, USB, and mDNS.
abstract final class AssistantDefaults {
  static const currentLaptopHost = '10.141.17.235';
  static const currentLaptopPort = 8765;

  static const List<String> fallbackHosts = [
    '10.141.17.235',
    '127.0.0.1',
    '10.0.2.2',
    'Asjads-MacBook-Pro.local',
  ];
}
