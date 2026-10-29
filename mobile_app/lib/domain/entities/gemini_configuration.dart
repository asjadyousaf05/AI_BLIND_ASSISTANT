/// Owner-supplied configuration for optional laptop-free text conversation.
/// Never include this value in diagnostics or conversation history.
class GeminiConfiguration {
  const GeminiConfiguration({required this.apiKey, this.model = defaultModel});

  static const defaultModel = 'gemini-3.1-flash-lite';
  final String apiKey;
  final String model;

  bool get isValid =>
      RegExp(r'^[A-Za-z0-9_-]{20,256}$').hasMatch(apiKey) &&
      RegExp(r'^gemini-[a-z0-9][a-z0-9.-]{0,79}$').hasMatch(model);

  @override
  String toString() => 'GeminiConfiguration(redacted)';
}
