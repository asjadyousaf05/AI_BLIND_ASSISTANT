/// Pairing credentials for the laptop AI assistant backend.
///
/// The backend URL and bearer token are persisted in Android secure storage.
/// They are never logged, printed, or included in debug output.
class AssistantCredential {
  const AssistantCredential({
    required this.backendUrl,
    required this.bearerToken,
    required this.userId,
    required this.displayName,
    required this.pairedAt,
    this.protocolVersion = 1,
  });

  /// Base URL of the FastAPI backend, e.g. `http://macbook.local:8765`.
  final String backendUrl;

  /// Opaque bearer token issued during the pairing handshake.
  final String bearerToken;

  /// Unique user ID on the backend.
  final String userId;

  /// Display name for the authenticated user.
  final String displayName;

  /// When the pairing was completed.
  final DateTime pairedAt;

  /// Backend protocol version accepted during pairing.
  final int protocolVersion;

  bool get isValid => backendUrl.isNotEmpty && bearerToken.isNotEmpty;

  AssistantCredential copyWith({
    String? backendUrl,
    String? bearerToken,
    String? userId,
    String? displayName,
    DateTime? pairedAt,
    int? protocolVersion,
  }) => AssistantCredential(
    backendUrl: backendUrl ?? this.backendUrl,
    bearerToken: bearerToken ?? this.bearerToken,
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    pairedAt: pairedAt ?? this.pairedAt,
    protocolVersion: protocolVersion ?? this.protocolVersion,
  );

  @override
  String toString() =>
      'AssistantCredential(userId: $userId, host: $backendUrl, '
      'protocol: v$protocolVersion)';
}
