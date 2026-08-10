enum ConnectionStatus {
  disconnected,
  searching,
  connecting,
  connected,
  reconnecting,
  error;

  bool get canRetry => switch (this) {
    ConnectionStatus.disconnected || ConnectionStatus.error => true,
    ConnectionStatus.searching ||
    ConnectionStatus.connecting ||
    ConnectionStatus.connected ||
    ConnectionStatus.reconnecting => false,
  };
}
