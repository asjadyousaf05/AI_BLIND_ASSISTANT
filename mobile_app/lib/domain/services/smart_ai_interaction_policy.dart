enum SmartAiSpeechLanguage { automatic, english, urdu }

/// Bounded Smart AI-only interaction rules; provider output is never a command.
abstract final class SmartAiInteractionPolicy {
  static final urduScript = RegExp(
    r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]',
  );
  static String responseLanguageInstruction(
    String question, {
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) =>
      language == SmartAiSpeechLanguage.urdu ||
          (language == SmartAiSpeechLanguage.automatic &&
              urduScript.hasMatch(question))
      ? 'Answer this latest question in Urdu using Urdu script, even if earlier messages used English. Keep the spoken answer brief.'
      : 'Answer this latest question in English, even if earlier messages used Urdu. Keep the spoken answer brief.';

  static bool isGoodbye(String text) {
    final phrase = text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?،۔؟]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return const {
      'goodbye smart ai',
      'good bye smart ai',
      'bye smart ai',
      'goodbye smart a i',
      'good bye smart a i',
      'خدا حافظ سمارٹ اے آئی',
      'خداحافظ سمارٹ اے آئی',
      'خدا حافظ سمارٹ اے ائی',
      'الوداع سمارٹ اے آئی',
    }.contains(phrase);
  }
}
