/// The structured response returned by the FastAPI assistant backend.
///
/// This is the validated, deserialized form of the JSON protocol.
/// The mobile app never acts on raw JSON from the model.
class AssistantResponse {
  const AssistantResponse({
    required this.responseText,
    required this.requestId,
    this.toolCall,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
  });

  /// The human-readable response text to speak to the user.
  final String responseText;

  /// Unique request ID for idempotency and audit.
  final String requestId;

  /// Optional structured tool call proposed by the model.
  final AssistantToolCall? toolCall;

  /// Whether the user must explicitly confirm before the action executes.
  final bool requiresConfirmation;

  /// Spoken confirmation prompt if [requiresConfirmation] is true.
  final String? confirmationPrompt;

  bool get hasToolCall => toolCall != null;

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      responseText: json['response_text'] as String? ?? '',
      requestId: json['request_id'] as String? ?? '',
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
      confirmationPrompt: json['confirmation_prompt'] as String?,
      toolCall: json['tool_call'] == null
          ? null
          : AssistantToolCall.fromJson(
              json['tool_call'] as Map<String, dynamic>,
            ),
    );
  }
}

/// Structured tool call proposed by the AI model.
class AssistantToolCall {
  const AssistantToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;

  factory AssistantToolCall.fromJson(Map<String, dynamic> json) {
    return AssistantToolCall(
      name: json['name'] as String,
      arguments:
          (json['arguments'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  @override
  String toString() => 'AssistantToolCall(name: $name, args: $arguments)';
}
