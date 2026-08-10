class WearableProtocolException implements Exception {
  const WearableProtocolException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'WearableProtocolException($code: $message)';
}

class WearableRemoteException implements Exception {
  const WearableRemoteException({
    required this.code,
    required this.message,
    required this.retryable,
    this.requestMessageId,
  });

  final String code;
  final String message;
  final bool retryable;
  final String? requestMessageId;

  @override
  String toString() => 'WearableRemoteException($code: $message)';
}
