class WearablePlatformException implements Exception {
  const WearablePlatformException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'WearablePlatformException($code: $message)';
}
