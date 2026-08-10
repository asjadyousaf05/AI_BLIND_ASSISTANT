enum WearableDeviceSource { discovered, saved, manual }

class WearableDevice {
  const WearableDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.source,
    this.serviceName = '_aiba-wearable._tcp',
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final WearableDeviceSource source;
  final String serviceName;

  Uri get webSocketUri =>
      Uri(scheme: 'ws', host: host, port: port, path: '/wearable/v1');

  WearableDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    WearableDeviceSource? source,
    String? serviceName,
  }) {
    return WearableDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      source: source ?? this.source,
      serviceName: serviceName ?? this.serviceName,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'source': source.name,
    'serviceName': serviceName,
  };

  static WearableDevice fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final name = map['name'];
    final host = map['host'];
    final port = map['port'];
    final serviceName = map['serviceName'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        host is! String ||
        host.isEmpty ||
        port is! int ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('Invalid discovered wearable device');
    }
    final rawSource = map['source'];
    final source = WearableDeviceSource.values.firstWhere(
      (value) => value.name == rawSource,
      orElse: () => WearableDeviceSource.discovered,
    );
    return WearableDevice(
      id: id,
      name: name,
      host: host,
      port: port,
      source: source,
      serviceName: serviceName is String && serviceName.isNotEmpty
          ? serviceName
          : '_aiba-wearable._tcp',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WearableDevice &&
        other.id == id &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(id, host, port);
}
