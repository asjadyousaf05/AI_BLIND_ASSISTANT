enum SmartAiAnswerProvider { groq, agentRouter }

/// Personal credentials for the explicitly enabled Smart AI conversation path.
class SmartAiCloudConfiguration {
  const SmartAiCloudConfiguration({
    required this.groqKey,
    this.routerKey = '',
    this.answerProvider = SmartAiAnswerProvider.agentRouter,
  });

  final String groqKey;
  final String routerKey;
  final SmartAiAnswerProvider answerProvider;
  static const transcriptionModel = 'whisper-large-v3';
  static const conversationModel = 'deepseek-v4-flash';
  static const groqConversationModel = 'openai/gpt-oss-20b';

  bool get usesGroqAnswers => answerProvider == SmartAiAnswerProvider.groq;
  String get answerProviderName => usesGroqAnswers ? 'Groq' : 'AgentRouter';
  String get answerModel =>
      usesGroqAnswers ? groqConversationModel : conversationModel;

  bool get isValid =>
      _validKey(groqKey) && (usesGroqAnswers || _validKey(routerKey));

  static bool _validKey(String value) =>
      value.length >= 16 &&
      value.length <= 512 &&
      RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value);

  @override
  String toString() => 'SmartAiCloudConfiguration(credentials: redacted)';
}
