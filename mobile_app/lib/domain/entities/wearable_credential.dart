import 'wearable_device.dart';

/// A revocable per-phone credential. [secret] must only be persisted by a
/// platform-backed secure credential repository and must never be logged.
class WearableCredential {
  const WearableCredential({
    required this.deviceId,
    required this.deviceName,
    required this.host,
    required this.port,
    required this.serviceName,
    required this.clientId,
    required this.credentialId,
    required this.secret,
    required this.createdAt,
  });

  final String deviceId;
  final String deviceName;
  final String host;
  final int port;
  final String serviceName;
  final String clientId;
  final String credentialId;
  final String secret;
  final DateTime createdAt;

  Map<String, Object?> toSecureMap() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'host': host,
    'port': port,
    'serviceName': serviceName,
    'clientId': clientId,
    'credentialId': credentialId,
    'secret': secret,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static WearableCredential fromSecureMap(Map<Object?, Object?> map) {
    final deviceId = map['deviceId'];
    final deviceName = map['deviceName'];
    final host = map['host'];
    final port = map['port'];
    final serviceName = map['serviceName'];
    final clientId = map['clientId'];
    final credentialId = map['credentialId'];
    final secret = map['secret'];
    final createdAt = map['createdAt'];
    if (deviceId is! String ||
        deviceId.isEmpty ||
        deviceName is! String ||
        deviceName.isEmpty ||
        host is! String ||
        host.isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        serviceName is! String ||
        serviceName.isEmpty ||
        clientId is! String ||
        clientId.isEmpty ||
        credentialId is! String ||
        credentialId.isEmpty ||
        secret is! String ||
        secret.isEmpty ||
        createdAt is! String) {
      throw const FormatException('Invalid wearable credential');
    }
    return WearableCredential(
      deviceId: deviceId,
      deviceName: deviceName,
      host: host,
      port: port,
      serviceName: serviceName,
      clientId: clientId,
      credentialId: credentialId,
      secret: secret,
      createdAt: DateTime.parse(createdAt).toUtc(),
    );
  }

  WearableDevice toDevice() => WearableDevice(
    id: deviceId,
    name: deviceName,
    host: host,
    port: port,
    source: WearableDeviceSource.saved,
    serviceName: serviceName,
  );
}
