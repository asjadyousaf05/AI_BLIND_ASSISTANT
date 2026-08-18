/// Result of executing a tool call on the mobile app side.
class AssistantToolResult {
  const AssistantToolResult({
    required this.toolName,
    required this.success,
    this.resultData,
    this.errorMessage,
  });

  final String toolName;
  final bool success;
  final Map<String, dynamic>? resultData;
  final String? errorMessage;

  factory AssistantToolResult.ok(
    String toolName, {
    Map<String, dynamic>? data,
  }) =>
      AssistantToolResult(toolName: toolName, success: true, resultData: data);

  factory AssistantToolResult.error(String toolName, String message) =>
      AssistantToolResult(
        toolName: toolName,
        success: false,
        errorMessage: message,
      );

  Map<String, dynamic> toJson() => {
    'tool_name': toolName,
    'success': success,
    if (resultData != null) 'result_data': resultData,
    if (errorMessage != null) 'error_message': errorMessage,
  };
}
