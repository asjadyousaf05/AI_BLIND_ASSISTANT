import '../enums/connection_status.dart';

class RaspberryPiConnectionState {
  const RaspberryPiConnectionState({required this.status, this.deviceName});

  static const disconnected = RaspberryPiConnectionState(
    status: ConnectionStatus.disconnected,
  );

  final ConnectionStatus status;
  final String? deviceName;

  RaspberryPiConnectionState copyWith({
    ConnectionStatus? status,
    String? deviceName,
  }) {
    return RaspberryPiConnectionState(
      status: status ?? this.status,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RaspberryPiConnectionState &&
        other.status == status &&
        other.deviceName == deviceName;
  }

  @override
  int get hashCode => Object.hash(status, deviceName);
}
