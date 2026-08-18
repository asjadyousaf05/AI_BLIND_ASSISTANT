import '../entities/assistant_credential.dart';
import '../entities/assistant_message.dart';
import '../entities/assistant_response.dart';
import '../entities/assistant_tool_result.dart';

/// Abstracts all communication with the laptop AI assistant backend.
///
/// Implementations must:
/// - Authenticate every request with the stored bearer token.
/// - Never log the token, audio bytes, or personal response content.
/// - Apply request timeouts and bounded retry.
/// - Translate HTTP and network errors into typed exceptions.
abstract interface class AssistantRepository {
  /// Checks if the backend is reachable and returns its protocol version.
  ///
  /// Returns `null` if the backend is unreachable.
  Future<int?> checkHealth(AssistantCredential credential);

  /// Performs a pairing handshake using [pairingCode] and returns a
  /// credential on success.
  ///
  /// Throws [AssistantAuthException] on rejected codes.
  /// Throws [AssistantNetworkException] on connectivity failures.
  Future<AssistantCredential> pair({
    required String backendUrl,
    required String pairingCode,
  });

  /// Sends a text query and receives a structured [AssistantResponse].
  Future<AssistantResponse> sendTextQuery({
    required AssistantCredential credential,
    required String query,
    required List<AssistantMessage> conversationHistory,
  });

  /// Uploads a recorded audio file and receives a structured [AssistantResponse].
  ///
  /// The [audioFilePath] must point to a temporary file that will be deleted
  /// by the caller immediately after this call returns.
  Future<AssistantResponse> sendAudioQuery({
    required AssistantCredential credential,
    required String audioFilePath,
    required List<AssistantMessage> conversationHistory,
  });

  /// Reports the result of a tool execution back to the backend so the
  /// conversation can continue and any persistent state is reconciled.
  Future<AssistantResponse> reportToolResult({
    required AssistantCredential credential,
    required String requestId,
    required AssistantToolResult result,
    required List<AssistantMessage> conversationHistory,
  });

  /// Retrieves the conversation history for the authenticated user.
  Future<List<AssistantMessage>> loadConversationHistory(
    AssistantCredential credential, {
    int limit = 20,
  });

  /// Clears the conversation history for the authenticated user.
  Future<void> clearConversationHistory(AssistantCredential credential);

  /// Fetches the list of reminders for the authenticated user.
  Future<List<Map<String, dynamic>>> listReminders(
    AssistantCredential credential,
  );

  /// Fetches the list of notes for the authenticated user.
  Future<List<Map<String, dynamic>>> listNotes(AssistantCredential credential);

  /// Requests a daily summary from the backend.
  Future<String> getDailySummary(AssistantCredential credential);
}

/// Thrown when the backend rejects authentication.
class AssistantAuthException implements Exception {
  const AssistantAuthException(this.message);
  final String message;
  @override
  String toString() => 'AssistantAuthException: $message';
}

/// Thrown when the backend is unreachable or returns an unexpected response.
class AssistantNetworkException implements Exception {
  const AssistantNetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'AssistantNetworkException($statusCode): $message';
}

/// Thrown when the backend returns an incompatible protocol version.
class AssistantVersionException implements Exception {
  const AssistantVersionException(this.serverVersion);
  final int serverVersion;
  @override
  String toString() =>
      'AssistantVersionException: server protocol v$serverVersion';
}
