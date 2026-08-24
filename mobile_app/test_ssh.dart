import 'dart:io';

/// Legacy connectivity probe retained without SSH credentials.
///
/// The production app uses authenticated wearable protocol pairing and never
/// embeds a Raspberry Pi login password.
Future<bool> wearableServiceIsReachable({
  String host = '10.141.17.148',
  int port = 8765,
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    return true;
  } on SocketException {
    return false;
  } finally {
    socket?.destroy();
  }
}
