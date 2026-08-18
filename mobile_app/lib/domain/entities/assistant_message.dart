/// Represents a single message in the assistant conversation history.
///
/// Immutable value object in the domain layer.
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.toolName,
  });

  final String id;
  final AssistantMessageRole role;
  final String text;
  final DateTime createdAt;

  /// Non-null when this message is the result of a tool execution.
  final String? toolName;

  bool get isUser => role == AssistantMessageRole.user;
  bool get isAssistant => role == AssistantMessageRole.assistant;
  bool get isSystem => role == AssistantMessageRole.system;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AssistantMessage(id: $id, role: $role, text: $text)';
}

enum AssistantMessageRole { user, assistant, system }
