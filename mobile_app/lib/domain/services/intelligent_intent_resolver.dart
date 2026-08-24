import '../entities/voice_command.dart';
import '../enums/voice_feature_context.dart';
import '../enums/voice_intent.dart';
import 'asr_correction_lexicon.dart';
import 'semantic_lexicon.dart';

/// The 14-stage offline intent resolution pipeline.
///
/// Pure Dart, no Flutter dependency, fully unit-testable.
/// Converts raw transcript text into a strongly-typed [VoiceCommand].
class IntelligentIntentResolver {
  IntelligentIntentResolver();

  /// Regular expression for removing filler words.
  static final _fillerPattern = RegExp(
    r'\b(um|uh|hmm|like|you know|actually|basically|well|so)\b',
  );

  /// Words that should not be treated as commands on their own.
  static const _nonsenseTokens = {'', '[unk]', 'unk', 'huh', 'ah', 'oh'};

  /// Minimum score to accept a match.
  static const _minAcceptScore = 0.6;

  /// Resolves a raw transcript into a [VoiceCommand].
  ///
  /// The [context] is used for context-aware disambiguation.
  /// The [isBargeIn] flag indicates the user is interrupting active TTS.
  VoiceCommand resolve(
    String rawTranscript, {
    VoiceFeatureContext context = VoiceFeatureContext.unknown,
    bool isBargeIn = false,
  }) {
    // Stage 1: Text normalization
    var text = _normalize(rawTranscript);
    if (_nonsenseTokens.contains(text)) {
      return VoiceCommand(
        intent: UnknownIntent(rawTranscript),
        matchScore: 0.0,
        matchType: VoiceMatchType.exact,
        originalTranscript: rawTranscript,
        normalizedTranscript: text,
      );
    }

    // Stage 2: Wake phrase removal
    text = _removeWakePhrase(text);
    if (text.isEmpty) {
      // Pure wake phrase with no command — the kernel handles this as a wake event.
      return VoiceCommand(
        intent: Greeting(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
        originalTranscript: rawTranscript,
        normalizedTranscript: text,
      );
    }

    // Stage 3: ASR correction
    text = AsrCorrectionLexicon.correct(text);

    // Stage 4: Filler removal
    text = text
        .replaceAll(_fillerPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Stage 4b: Polite request prefix stripping
    final strippedText = _stripRequestPrefixes(text);

    // Stage 5-6: Try exact alias matching first (highest confidence)
    final exactMatch =
        _tryExactMatch(text, context: context) ??
        (strippedText != text
            ? _tryExactMatch(strippedText, context: context)
            : null);
    if (exactMatch != null) {
      return exactMatch._withTranscripts(rawTranscript, text);
    }

    // Stage 7-8: Pattern matching for parameterized commands
    final patternMatch =
        _tryPatternMatch(text, context: context) ??
        (strippedText != text
            ? _tryPatternMatch(strippedText, context: context)
            : null);
    if (patternMatch != null) {
      return patternMatch._withTranscripts(rawTranscript, text);
    }

    // Stage 9: Context-aware semantic composition
    final semanticMatch =
        _trySemanticComposition(text, context: context) ??
        (strippedText != text
            ? _trySemanticComposition(strippedText, context: context)
            : null);
    if (semanticMatch != null) {
      return semanticMatch._withTranscripts(rawTranscript, text);
    }

    // Stage 10: Token similarity / fuzzy matching
    final fuzzyMatch =
        _tryFuzzyMatch(text, context: context) ??
        (strippedText != text
            ? _tryFuzzyMatch(strippedText, context: context)
            : null);
    if (fuzzyMatch != null) {
      return fuzzyMatch._withTranscripts(rawTranscript, text);
    }

    // Stage 11-14: No match found
    return VoiceCommand(
      intent: UnknownIntent(rawTranscript),
      matchScore: 0.0,
      matchType: VoiceMatchType.exact,
      originalTranscript: rawTranscript,
      normalizedTranscript: text,
    );
  }

  // ─────────────────── Stage 1: Normalization ───────────────────

  String _normalize(String text) =>
      text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  // ─────────────────── Stage 2: Wake Removal ────────────────────

  static final _wakePatterns = [
    RegExp(
      r'^(hey|hi|hello|ok|okay|yo)\s+vision\s*(ai|a\s*i|aye|eye)?\s*,?\s*',
    ),
    RegExp(r'^vision\s*(ai|a\s*i|aye|eye)?\s*,?\s*'),
  ];

  String _removeWakePhrase(String text) {
    for (final pattern in _wakePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return text.substring(match.end).trim();
      }
    }
    return text;
  }

  // ─────────────────── Stage 4b: Request Prefix Stripping ────────

  static final _requestPrefixes = [
    RegExp(
      r'^(please|can you please|could you please|would you please|can you|could you|would you|i want you to|i need you to|i want to|i need to|please can you|please could you)\s+',
      caseSensitive: false,
    ),
  ];

  String _stripRequestPrefixes(String text) {
    var result = text;
    for (final pattern in _requestPrefixes) {
      final match = pattern.firstMatch(result);
      if (match != null) {
        result = result.substring(match.end).trim();
      }
    }
    return result;
  }

  // ─────────────────── Stage 5-6: Exact Matching ────────────────

  VoiceCommand? _tryExactMatch(
    String text, {
    required VoiceFeatureContext context,
  }) {
    final match = _exactAliases[text];
    if (match != null) {
      return VoiceCommand(
        intent: match,
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );
    }

    // Check contextual aliases
    final contextual = _contextualAliases[context];
    if (contextual != null) {
      final contextMatch = contextual[text];
      if (contextMatch != null) {
        return VoiceCommand(
          intent: contextMatch,
          matchScore: 1.0,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    return null;
  }

  // ─────────────────── Stage 7-8: Pattern Matching ──────────────

  VoiceCommand? _tryPatternMatch(
    String text, {
    required VoiceFeatureContext context,
  }) {
    if (context == VoiceFeatureContext.scannerReading &&
        (text.contains('line') || text.contains('sentence'))) {
      final lineNumber = _extractReadingLineNumber(text);
      if (lineNumber != null) {
        return VoiceCommand(
          intent: ReadingGoToLine(lineNumber),
          matchScore: 0.98,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    // Sensitivity pattern
    for (final entry in _sensitivityPatterns.entries) {
      if (text.contains(entry.key) && _containsSensitivityKeyword(text)) {
        return VoiceCommand(
          intent: SetDetectionSensitivity(entry.value),
          matchScore: 0.9,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    // Feedback mode pattern
    if (text.contains('feedback')) {
      final mode = _extractFeedbackMode(text);
      if (mode != null) {
        return VoiceCommand(
          intent: SetFeedbackMode(mode),
          matchScore: 0.9,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    // Boolean settings pattern
    for (final entry in _booleanSettingPatterns.entries) {
      if (text.contains(entry.key)) {
        final enabled = _extractEnabled(text);
        if (enabled != null) {
          return VoiceCommand(
            intent: SetBooleanSetting(entry.value, enabled: enabled),
            matchScore: 0.9,
            matchType: VoiceMatchType.alias,
          );
        }
      }
    }

    // Flashlight pattern
    if (text.contains('flashlight') || text.contains('torch')) {
      final enabled = _extractEnabled(text);
      if (enabled != null) {
        return VoiceCommand(
          intent: SetFlashlight(enabled: enabled),
          matchScore: 0.95,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    // General assistant speech rate. Reader-specific phrases such as
    // "speak slower" are resolved by exact contextual aliases first.
    if (text.contains('speech rate') || text.contains('voice speed')) {
      final rate = _extractSpeechRate(text);
      if (rate != null) {
        return VoiceCommand(
          intent: SetSpeechRate(rate),
          matchScore: 0.9,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    // Cooldown pattern
    if (text.contains('cooldown') ||
        text.contains('announcement interval') ||
        text.contains('alert interval')) {
      final seconds = _extractNumber(text);
      if (seconds != null && seconds >= 1 && seconds <= 30) {
        return VoiceCommand(
          intent: SetAnnouncementCooldown(seconds),
          matchScore: 0.9,
          matchType: VoiceMatchType.alias,
        );
      }
    }

    return null;
  }

  // ─────────────────── Stage 9: Semantic Composition ────────────

  VoiceCommand? _trySemanticComposition(
    String text, {
    required VoiceFeatureContext context,
  }) {
    final verb = SemanticLexicon.extractVerb(text);
    final entity = SemanticLexicon.extractEntity(text);

    if (verb == null && entity == null) return null;

    final intent = _composeIntent(verb, entity, context: context);
    if (intent == null) return null;

    return VoiceCommand(
      intent: intent,
      matchScore: 0.75,
      matchType: VoiceMatchType.semantic,
    );
  }

  VoiceIntent? _composeIntent(
    String? verb,
    String? entity, {
    required VoiceFeatureContext context,
  }) {
    // Emergency: DEACTIVATE + everything
    if (verb == 'DEACTIVATE' && (entity == null || entity == 'READING')) {
      // Context-dependent: in scanner → stop reading; in mobile → stop detection
      if (context == VoiceFeatureContext.scannerReading) {
        return const Silence();
      }
      if (context == VoiceFeatureContext.mobileDetection && entity == null) {
        return const StopMobileDetection();
      }
    }

    // Navigation compositions
    if (verb == 'NAVIGATE') {
      return switch (entity) {
        'HOME' => const NavigateHome(),
        'SETTINGS' => const NavigateSettings(),
        'SCANNER' => const NavigateScanner(),
        'SMART_AI' => const NavigateSmartAi(),
        'MOBILE_DETECTION' => const NavigateMobileAssistance(),
        'RASPBERRY_PI' => const NavigateRaspberryPi(),
        'MODES' => const NavigateModeSelection(),
        'SAFETY' => const NavigateSafety(),
        'HELP' => const NavigateHelp(),
        _ => null,
      };
    }

    if (entity == 'SMART_AI' && verb == 'ACTIVATE') {
      return const NavigateSmartAi();
    }

    // Mobile Detection compositions
    if (entity == 'MOBILE_DETECTION') {
      return switch (verb) {
        'ACTIVATE' => const StartMobileDetection(),
        'DEACTIVATE' => const StopMobileDetection(),
        'PAUSE' => const PauseMobileDetection(),
        'RESUME' => const ResumeMobileDetection(),
        'QUERY' => const GetMobileDetectionStatus(),
        _ => null,
      };
    }

    // Raspberry Pi compositions
    if (entity == 'RASPBERRY_PI') {
      return switch (verb) {
        'ACTIVATE' => const StartWearable(),
        'DEACTIVATE' => const StopWearable(),
        'PAUSE' => const PauseWearable(),
        'RESUME' => const ResumeWearable(),
        'CONNECT' => const ConnectPi(),
        'DISCONNECT' => const DisconnectPi(),
        'DISCOVER' => const DiscoverPi(),
        'QUERY' => const GetPiStatus(),
        _ => null,
      };
    }

    // Scanner compositions
    if (entity == 'SCANNER') {
      return switch (verb) {
        'SCAN' || 'ACTIVATE' => const ScanDocument(),
        'NAVIGATE' => const NavigateScanner(),
        _ => null,
      };
    }

    // Utility compositions
    if (entity == 'TIME' && (verb == 'QUERY' || verb == null)) {
      return const GetCurrentTime();
    }
    if (entity == 'DATE' && (verb == 'QUERY' || verb == null)) {
      return const GetCurrentDate();
    }
    if (entity == 'BATTERY' && (verb == 'QUERY' || verb == null)) {
      return const GetBatteryStatus();
    }

    // Flashlight compositions
    if (entity == 'FLASHLIGHT') {
      return switch (verb) {
        'ACTIVATE' => const SetFlashlight(enabled: true),
        'DEACTIVATE' => const SetFlashlight(enabled: false),
        _ => null,
      };
    }

    // Environment mode
    if (entity == 'INDOOR') return const SetEnvironmentMode('indoor');
    if (entity == 'OUTDOOR') return const SetEnvironmentMode('outdoor');

    return null;
  }

  // ─────────────────── Stage 10: Fuzzy Matching ─────────────────

  VoiceCommand? _tryFuzzyMatch(
    String text, {
    required VoiceFeatureContext context,
  }) {
    // Check conversation patterns
    final conversationMatch = _tryConversationMatch(text);
    if (conversationMatch != null) return conversationMatch;

    // Token-level similarity against exact aliases
    double bestScore = 0;
    VoiceIntent? bestIntent;

    final textTokens = text.split(' ').where((t) => t.isNotEmpty).toSet();
    if (textTokens.isEmpty) return null;

    for (final entry in _exactAliases.entries) {
      final aliasTokens = entry.key
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toSet();
      if (aliasTokens.isEmpty) continue;

      final intersection = textTokens.intersection(aliasTokens);
      final union = textTokens.union(aliasTokens);
      final jaccard = intersection.length / union.length;

      if (intersection.length >= 2 &&
          jaccard > bestScore &&
          jaccard >= _minAcceptScore) {
        bestScore = jaccard;
        bestIntent = entry.value;
      }
    }

    if (bestIntent != null) {
      return VoiceCommand(
        intent: bestIntent,
        matchScore: bestScore,
        matchType: VoiceMatchType.fuzzy,
      );
    }

    return null;
  }

  VoiceCommand? _tryConversationMatch(String text) {
    for (final entry in _conversationPatterns.entries) {
      if (text.contains(entry.key)) {
        return VoiceCommand(
          intent: entry.value,
          matchScore: 0.85,
          matchType: VoiceMatchType.conversation,
        );
      }
    }
    return null;
  }

  // ─────────────────── Helper Extractors ────────────────────────

  bool _containsSensitivityKeyword(String text) =>
      text.contains('sensitivity') ||
      text.contains('confidence') ||
      text.contains('accuracy') ||
      text.contains('detection level') ||
      text.contains('detection threshold');

  static const _sensitivityPatterns = {
    'low': 'low',
    'reduce': 'low',
    'decrease': 'low',
    'less': 'low',
    'lower': 'low',
    'minimum': 'low',
    'high': 'high',
    'increase': 'high',
    'more': 'high',
    'higher': 'high',
    'maximum': 'high',
    'raise': 'high',
    'boost': 'high',
    'medium': 'medium',
    'normal': 'medium',
    'default': 'medium',
    'middle': 'medium',
    'moderate': 'medium',
  };

  String? _extractFeedbackMode(String text) {
    if (text.contains('vibration') &&
        (text.contains('audio') ||
            text.contains('speech') ||
            text.contains('both') ||
            text.contains('and'))) {
      return 'both';
    }
    if (text.contains('vibration')) return 'vibration';
    if (text.contains('audio') ||
        text.contains('speech') ||
        text.contains('sound') ||
        text.contains('voice')) {
      return 'audio';
    }
    return null;
  }

  static const _booleanSettingPatterns = {
    'high contrast': 'high_contrast',
    'large text': 'large_text',
    'big text': 'large_text',
    'bigger text': 'large_text',
    'reduced motion': 'reduced_motion',
    'reduce motion': 'reduced_motion',
    'vibration': 'vibration',
    'haptic': 'vibration',
    'haptics': 'vibration',
    'hands free': 'hands_free',
    'hands-free': 'hands_free',
  };

  bool? _extractEnabled(String text) {
    if (_containsAny(text, const ['disable', 'turn off', 'switch off']) ||
        RegExp(r'\boff\b').hasMatch(text)) {
      return false;
    }
    if (_containsAny(text, const ['enable', 'turn on', 'switch on']) ||
        RegExp(r'\bon\b').hasMatch(text)) {
      return true;
    }
    return null;
  }

  int? _extractNumber(String text) {
    const wordNumbers = {
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'fifteen': 15,
      'twenty': 20,
      'thirty': 30,
    };
    for (final entry in wordNumbers.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(text)) {
        return entry.value;
      }
    }
    final digitMatch = RegExp(r'\b([1-9]|[12][0-9]|30)\b').firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!);
    }
    return null;
  }

  int? _extractReadingLineNumber(String text) {
    final digitMatch = RegExp(r'\b([1-9][0-9]{0,2})\b').firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!);
    }

    final normalized = text.replaceAll('-', ' ');
    final afterLabel = RegExp(
      r'\b(?:line|sentence)(?:\s+number)?\s+([a-z ]+)$',
    ).firstMatch(normalized);
    final beforeLabel = RegExp(
      r'\b((?:[a-z]+\s+){0,5}[a-z]+)\s+(?:line|sentence)\b',
    ).firstMatch(normalized);
    final numberPhrase = afterLabel?.group(1) ?? beforeLabel?.group(1);
    if (numberPhrase == null) return null;

    const values = <String, int>{
      'one': 1,
      'first': 1,
      'two': 2,
      'second': 2,
      'three': 3,
      'third': 3,
      'four': 4,
      'fourth': 4,
      'five': 5,
      'fifth': 5,
      'six': 6,
      'sixth': 6,
      'seven': 7,
      'seventh': 7,
      'eight': 8,
      'eighth': 8,
      'nine': 9,
      'ninth': 9,
      'ten': 10,
      'tenth': 10,
      'eleven': 11,
      'eleventh': 11,
      'twelve': 12,
      'twelfth': 12,
      'thirteen': 13,
      'thirteenth': 13,
      'fourteen': 14,
      'fourteenth': 14,
      'fifteen': 15,
      'fifteenth': 15,
      'sixteen': 16,
      'sixteenth': 16,
      'seventeen': 17,
      'seventeenth': 17,
      'eighteen': 18,
      'eighteenth': 18,
      'nineteen': 19,
      'nineteenth': 19,
      'twenty': 20,
      'twentieth': 20,
      'thirty': 30,
      'thirtieth': 30,
      'forty': 40,
      'fortieth': 40,
      'fifty': 50,
      'fiftieth': 50,
      'sixty': 60,
      'sixtieth': 60,
      'seventy': 70,
      'seventieth': 70,
      'eighty': 80,
      'eightieth': 80,
      'ninety': 90,
      'ninetieth': 90,
    };

    var current = 0;
    var foundNumber = false;
    for (final token in numberPhrase.trim().split(RegExp(r'\s+'))) {
      if (token == 'hundred' || token == 'hundredth') {
        current = (current == 0 ? 1 : current) * 100;
        foundNumber = true;
        continue;
      }
      final value = values[token];
      if (value != null) {
        current += value;
        foundNumber = true;
      }
    }
    return foundNumber && current > 0 && current <= 999 ? current : null;
  }

  String? _extractSpeechRate(String text) {
    if (_containsAny(text, const ['slow', 'slower', 'decrease', 'lower'])) {
      return 'slow';
    }
    if (_containsAny(text, const ['fast', 'faster', 'increase', 'raise'])) {
      return 'fast';
    }
    if (_containsAny(text, const ['normal', 'default', 'standard'])) {
      return 'normal';
    }
    return null;
  }

  static bool _containsAny(String text, List<String> phrases) =>
      phrases.any(text.contains);

  // ─────────────────── Exact Alias Registry ─────────────────────

  static final _exactAliases = <String, VoiceIntent>{
    // Emergency
    'stop everything': const EmergencyStop(),
    'stop all': const EmergencyStop(),
    'emergency stop': const EmergencyStop(),
    'halt everything': const EmergencyStop(),

    // Silence
    'stop speaking': const Silence(),
    'stop talking': const Silence(),
    'stop reading': const Silence(),
    'stop voice': const Silence(),
    'stop audio': const Silence(),
    'be quiet': const Silence(),
    'quiet': const Silence(),
    'silence': const Silence(),
    'shut up': const Silence(),
    'mute': const Silence(),
    'mute audio': const Silence(),
    'mute voice': const Silence(),
    'mute speech': const Silence(),
    'shh': const Silence(),
    'hush': const Silence(),

    // Mobile Detection
    'start mobile mode': const StartMobileDetection(),
    'start detection': const StartMobileDetection(),
    'start object detection': const StartMobileDetection(),
    'start mobile detection': const StartMobileDetection(),
    'start camera': const StartMobileDetection(),
    'start seeing': const StartMobileDetection(),
    'start vision': const StartMobileDetection(),
    'start mobile assistance': const StartMobileDetection(),
    'start assistance': const StartMobileDetection(),
    'start detecting': const StartMobileDetection(),
    'detect objects': const StartMobileDetection(),
    'help me see': const StartMobileDetection(),
    'run detection': const StartMobileDetection(),
    'begin detection': const StartMobileDetection(),
    'enable detection': const StartMobileDetection(),
    'activate detection': const StartMobileDetection(),
    'turn on detection': const StartMobileDetection(),
    'look around': const StartMobileDetection(),
    'start obstacle detection': const StartMobileDetection(),

    'stop mobile mode': const StopMobileDetection(),
    'stop detection': const StopMobileDetection(),
    'stop the detection': const StopMobileDetection(),
    'stop detecting': const StopMobileDetection(),
    'stop camera': const StopMobileDetection(),
    'stop vision': const StopMobileDetection(),
    'stop seeing': const StopMobileDetection(),
    'stop mobile assistance': const StopMobileDetection(),
    'stop model': const StopMobileDetection(),
    'stop phone mode': const StopMobileDetection(),
    'stop object detection': const StopMobileDetection(),
    'turn off detection': const StopMobileDetection(),
    'turn off camera': const StopMobileDetection(),
    'turn off vision': const StopMobileDetection(),
    'turn off mobile mode': const StopMobileDetection(),
    'turn off assistance': const StopMobileDetection(),
    'end detection': const StopMobileDetection(),
    'close detection': const StopMobileDetection(),
    'exit detection': const StopMobileDetection(),
    'kill detection': const StopMobileDetection(),
    'deactivate detection': const StopMobileDetection(),
    'disable detection': const StopMobileDetection(),

    'pause detection': const PauseMobileDetection(),
    'pause camera': const PauseMobileDetection(),
    'pause vision': const PauseMobileDetection(),
    'pause mobile mode': const PauseMobileDetection(),
    'pause seeing': const PauseMobileDetection(),
    'pause assistance': const PauseMobileDetection(),

    'resume detection': const ResumeMobileDetection(),
    'resume camera': const ResumeMobileDetection(),
    'resume vision': const ResumeMobileDetection(),
    'resume mobile mode': const ResumeMobileDetection(),
    'resume seeing': const ResumeMobileDetection(),
    'resume assistance': const ResumeMobileDetection(),

    'detection status': const GetMobileDetectionStatus(),
    'mobile mode status': const GetMobileDetectionStatus(),
    'is detection running': const GetMobileDetectionStatus(),
    'camera status': const GetMobileDetectionStatus(),

    'what do you see': const ReadRecentDetections(),
    'what is nearby': const ReadRecentDetections(),
    "what's nearby": const ReadRecentDetections(),
    'recent detections': const ReadRecentDetections(),
    'detected objects': const ReadRecentDetections(),
    'what have you detected': const ReadRecentDetections(),
    'what did you detect': const ReadRecentDetections(),
    'what objects': const ReadRecentDetections(),
    'read recent detections': const ReadRecentDetections(),

    // Document Scanner
    'scan document': const ScanDocument(),
    'scan the document': const ScanDocument(),
    'scan this document': const ScanDocument(),
    'scan this': const ScanDocument(),
    'scan this page': const ScanDocument(),
    'read document': const ScanDocument(),
    'read the document': const ScanDocument(),
    'read this': const ScanDocument(),
    'read page': const ScanDocument(),
    'read this page': const ScanDocument(),
    'read this document': const ScanDocument(),
    'read the text': const ScanDocument(),
    'scan page': const ScanDocument(),
    'read text': const ScanDocument(),
    'scan text': const ScanDocument(),
    'scan now': const ScanDocument(),
    'scan it': const ScanDocument(),
    'start scan': const ScanDocument(),
    'start scanning': const ScanDocument(),
    'begin scanning': const ScanDocument(),
    'take picture': const ScanDocument(),
    'take photo': const ScanDocument(),
    'take a picture': const ScanDocument(),
    'take a photo': const ScanDocument(),
    'capture': const ScanDocument(),
    'capture page': const ScanDocument(),
    'capture this page': const ScanDocument(),
    'capture document': const ScanDocument(),
    'capture photo': const ScanDocument(),
    'capture now': const ScanDocument(),

    'scan again': const RescanDocument(),
    'scan another': const RescanDocument(),
    'scan another document': const RescanDocument(),
    'scan another page': const RescanDocument(),
    'scan next page': const RescanDocument(),
    'capture another page': const RescanDocument(),
    'capture another': const RescanDocument(),
    'read another page': const RescanDocument(),
    'rescan': const RescanDocument(),
    'new scan': const RescanDocument(),
    'try again': const RescanDocument(),

    'read again': const ReadDocumentAgain(),
    'read text again': const ReadDocumentAgain(),
    'read document again': const ReadDocumentAgain(),
    'read it again': const ReadDocumentAgain(),

    // Reader Controls
    'pause reading': const ReadingPause(),
    'pause the reading': const ReadingPause(),
    'pause it': const ReadingPause(),
    'pause audio': const ReadingPause(),
    'pause speech': const ReadingPause(),
    'hold on': const ReadingPause(),
    'wait a moment': const ReadingPause(),
    'stop for a moment': const ReadingPause(),

    'resume reading': const ReadingResume(),
    'start reading': const ReadingResume(),
    'start the reading': const ReadingResume(),
    'begin reading': const ReadingResume(),
    'begin the reading': const ReadingResume(),
    'read aloud': const ReadingResume(),
    'play document': const ReadingResume(),
    'resume audio': const ReadingResume(),
    'resume speech': const ReadingResume(),
    'continue reading': const ReadingResume(),
    'keep reading': const ReadingResume(),
    'carry on': const ReadingResume(),
    'keep going': const ReadingResume(),
    'start reading again': const ReadingResume(),
    'continue from here': const ReadingResume(),
    'play': const ReadingResume(),
    'unpause': const ReadingResume(),

    'next': const ReadingNext(),
    'next line': const ReadingNext(),
    'next sentence': const ReadingNext(),
    'go next': const ReadingNext(),
    'move next': const ReadingNext(),
    'move forward': const ReadingNext(),
    'go forward': const ReadingNext(),
    'read next': const ReadingNext(),
    'read the next sentence': const ReadingNext(),
    'move to next sentence': const ReadingNext(),
    'skip this sentence': const ReadingNext(),
    'continue to next': const ReadingNext(),
    'skip line': const ReadingNext(),
    'skip sentence': const ReadingNext(),
    'skip ahead': const ReadingNext(),
    'forward': const ReadingNext(),
    'skip': const ReadingNext(),

    'previous': const ReadingPrevious(),
    'previous line': const ReadingPrevious(),
    'previous sentence': const ReadingPrevious(),
    'go previous': const ReadingPrevious(),
    'go back one sentence': const ReadingPrevious(),
    'read previous': const ReadingPrevious(),
    'read the previous sentence': const ReadingPrevious(),
    'what was before this': const ReadingPrevious(),
    'rewind': const ReadingPrevious(),

    'repeat': const ReadingRepeat(),
    'repeat that': const ReadingRepeat(),
    'repeat this': const ReadingRepeat(),
    'repeat line': const ReadingRepeat(),
    'repeat sentence': const ReadingRepeat(),
    'repeat this sentence': const ReadingRepeat(),
    'repeat current sentence': const ReadingRepeat(),
    'say line again': const ReadingRepeat(),
    'read line again': const ReadingRepeat(),
    'say that again': const ReadingRepeat(),
    'read that again': const ReadingRepeat(),
    'read that sentence again': const ReadingRepeat(),
    'say again': const ReadingRepeat(),
    'again': const ReadingRepeat(),
    'one more time': const ReadingRepeat(),
    'repeat text': const ReadingRepeat(),
    'what did you just say': const ReadingRepeat(),
    'say the sentence again': const ReadingRepeat(),

    'restart': const ReadingRestart(),
    'restart reading': const ReadingRestart(),
    'start again': const ReadingRestart(),
    'start over': const ReadingRestart(),
    'start from beginning': const ReadingRestart(),
    'start from the beginning': const ReadingRestart(),
    'read from beginning': const ReadingRestart(),
    'read from the beginning': const ReadingRestart(),
    'go to beginning': const ReadingRestart(),
    'begin again': const ReadingRestart(),
    'restart document': const ReadingRestart(),
    'from the beginning': const ReadingRestart(),
    'from the top': const ReadingRestart(),
    'first line': const ReadingRestart(),
    'first sentence': const ReadingRestart(),
    'go to first line': const ReadingRestart(),
    'go to the first line': const ReadingRestart(),
    'read first line': const ReadingRestart(),
    'read the first line': const ReadingRestart(),
    'beginning of document': const ReadingRestart(),
    'top of document': const ReadingRestart(),

    'last line': const ReadingLast(),
    'last sentence': const ReadingLast(),
    'final line': const ReadingLast(),
    'final sentence': const ReadingLast(),
    'go to last line': const ReadingLast(),
    'go to the last line': const ReadingLast(),
    'read last line': const ReadingLast(),
    'read the last line': const ReadingLast(),
    'end of document': const ReadingLast(),
    'bottom of document': const ReadingLast(),

    'spell': const ReadingSpell(),
    'spell it': const ReadingSpell(),
    'spell that': const ReadingSpell(),
    'spell out': const ReadingSpell(),
    'spell this': const ReadingSpell(),
    'spell word': const ReadingSpell(),
    'spell this word': const ReadingSpell(),
    'spell current word': const ReadingSpell(),
    'spell the word': const ReadingSpell(),
    'spell sentence': const ReadingSpell(),
    'spell this sentence': const ReadingSpell(),
    'spell current sentence': const ReadingSpell(),
    'spell current line': const ReadingSpell(),
    'spell this line': const ReadingSpell(),
    'spell the current line': const ReadingSpell(),
    'spell the sentence': const ReadingSpell(),
    'spell it out': const ReadingSpell(),
    'spelling': const ReadingSpell(),
    'read letter by letter': const ReadingSpell(),
    'letter by letter': const ReadingSpell(),

    'study mode': const SetReadingProfile('learning'),
    'learning mode': const SetReadingProfile('learning'),
    'slow down': const SetReadingProfile('learning'),
    'speak slower': const SetReadingProfile('learning'),
    'read slowly': const SetReadingProfile('learning'),
    'slow mode': const SetReadingProfile('learning'),
    'make it slower': const SetReadingProfile('learning'),
    'make reading slower': const SetReadingProfile('learning'),
    'make the reading slower': const SetReadingProfile('learning'),

    'fast mode': const SetReadingProfile('skim'),
    'skim mode': const SetReadingProfile('skim'),
    'speed up': const SetReadingProfile('skim'),
    'speak faster': const SetReadingProfile('skim'),
    'read faster': const SetReadingProfile('skim'),
    'make it faster': const SetReadingProfile('skim'),
    'make reading faster': const SetReadingProfile('skim'),
    'make the reading faster': const SetReadingProfile('skim'),

    'normal speed': const SetReadingProfile('normal'),
    'normal mode': const SetReadingProfile('normal'),
    'standard mode': const SetReadingProfile('normal'),
    'standard speed': const SetReadingProfile('normal'),
    'read normally': const SetReadingProfile('normal'),
    'reset reading speed': const SetReadingProfile('normal'),

    'switch camera': const SwitchScannerCamera(),
    'flip camera': const SwitchScannerCamera(),
    'change camera': const SwitchScannerCamera(),
    'toggle camera': const SwitchScannerCamera(),

    'copy': const CopyScannedText(),
    'copy text': const CopyScannedText(),
    'copy the text': const CopyScannedText(),
    'copy document': const CopyScannedText(),
    'copy this document': const CopyScannedText(),
    'copy all text': const CopyScannedText(),
    'copy everything': const CopyScannedText(),
    'copy to clipboard': const CopyScannedText(),
    'copy result': const CopyScannedText(),

    // Smart AI Document integration
    'ask ai about this': const NavigateSmartAi(),
    'ask ai about this document': const NavigateSmartAi(),
    'send this to ai': const NavigateSmartAi(),
    'send document to ai': const NavigateSmartAi(),
    'explain this with ai': const NavigateSmartAi(),

    // Environment Mode
    'indoor mode': const SetEnvironmentMode('indoor'),
    'home mode': const SetEnvironmentMode('indoor'),
    'switch to indoor': const SetEnvironmentMode('indoor'),
    'outdoor mode': const SetEnvironmentMode('outdoor'),
    'street mode': const SetEnvironmentMode('outdoor'),
    'switch to outdoor': const SetEnvironmentMode('outdoor'),
    'auto environment': const SetEnvironmentMode('auto'),
    'auto detection mode': const SetEnvironmentMode('auto'),
    'automatic environment': const SetEnvironmentMode('auto'),

    // Navigation
    'go home': const NavigateHome(),
    'open home': const NavigateHome(),
    'home screen': const NavigateHome(),
    'main screen': const NavigateHome(),

    'open settings': const NavigateSettings(),
    'go to settings': const NavigateSettings(),
    'show settings': const NavigateSettings(),
    'open preferences': const NavigateSettings(),

    'open scanner': const NavigateScanner(),
    'open document scanner': const NavigateScanner(),
    'open ocr': const NavigateScanner(),
    'open reader': const NavigateScanner(),
    'go to scanner': const NavigateScanner(),

    'open smart ai': const NavigateSmartAi(),
    'start smart ai': const NavigateSmartAi(),
    'launch smart ai': const NavigateSmartAi(),
    'go to smart ai': const NavigateSmartAi(),
    'switch to smart ai': const NavigateSmartAi(),
    'switch to online mode': const NavigateSmartAi(),
    'start online assistant': const NavigateSmartAi(),
    'talk to ai': const NavigateSmartAi(),
    'ask ai': const NavigateSmartAi(),
    'open ai chat': const NavigateSmartAi(),
    'open assistant': const NavigateSmartAi(),
    'talk to assistant': const NavigateSmartAi(),
    'open online assistant': const NavigateSmartAi(),

    'open mobile mode': const NavigateMobileAssistance(),
    'go to mobile mode': const NavigateMobileAssistance(),
    'open camera screen': const NavigateMobileAssistance(),

    'open raspberry pi': const NavigateRaspberryPi(),
    'open pi': const NavigateRaspberryPi(),
    'pi screen': const NavigateRaspberryPi(),

    'select mode': const NavigateModeSelection(),
    'choose mode': const NavigateModeSelection(),
    'mode selection': const NavigateModeSelection(),
    'open modes': const NavigateModeSelection(),
    'change mode': const NavigateModeSelection(),

    'open safety': const NavigateSafety(),
    'about safety': const NavigateSafety(),
    'safety screen': const NavigateSafety(),

    'open help': const NavigateHelp(),
    'help screen': const NavigateHelp(),
    'open user guide': const NavigateHelp(),

    'go back': const NavigateBack(),
    'navigate back': const NavigateBack(),
    'return back': const NavigateBack(),
    'previous screen': const NavigateBack(),

    // Pi/Wearable
    'raspberry pi status': const GetPiStatus(),
    'pi status': const GetPiStatus(),
    'wearable status': const GetPiStatus(),
    'is pi connected': const GetPiStatus(),

    'find raspberry pi': const DiscoverPi(),
    'discover pi': const DiscoverPi(),
    'scan for raspberry pi': const DiscoverPi(),
    'search for pi': const DiscoverPi(),

    'connect to raspberry pi': const ConnectPi(),
    'connect pi': const ConnectPi(),
    'pair pi': const ConnectPi(),

    'disconnect raspberry pi': const DisconnectPi(),
    'disconnect pi': const DisconnectPi(),
    'unpair pi': const DisconnectPi(),

    'start wearable mode': const StartWearable(),
    'start pi detection': const StartWearable(),
    'stop wearable mode': const StopWearable(),
    'stop pi detection': const StopWearable(),
    'pause wearable mode': const PauseWearable(),
    'resume wearable mode': const ResumeWearable(),

    // Utility
    'what time is it': const GetCurrentTime(),
    'what is the time': const GetCurrentTime(),
    'current time': const GetCurrentTime(),
    'tell me the time': const GetCurrentTime(),

    'what is today': const GetCurrentDate(),
    'what is the date': const GetCurrentDate(),
    'current date': const GetCurrentDate(),
    'what day is it': const GetCurrentDate(),
    'tell me the date': const GetCurrentDate(),

    'battery level': const GetBatteryStatus(),
    'battery status': const GetBatteryStatus(),
    'battery percentage': const GetBatteryStatus(),
    'how much battery': const GetBatteryStatus(),
    'check battery': const GetBatteryStatus(),

    'assistant status': const GetAssistantConnectionStatus(),
    'connection status': const GetAssistantConnectionStatus(),
    'laptop status': const GetAssistantConnectionStatus(),

    'read settings': const GetAppSettings(),
    'current settings': const GetAppSettings(),
    'settings status': const GetAppSettings(),

    'change feedback mode to audio': const SetFeedbackMode('audio'),
    'set feedback mode to audio': const SetFeedbackMode('audio'),
    'use audio feedback': const SetFeedbackMode('audio'),
    'audio feedback only': const SetFeedbackMode('audio'),
    'change feedback mode to vibration': const SetFeedbackMode('vibration'),
    'set feedback mode to vibration': const SetFeedbackMode('vibration'),
    'use vibration feedback': const SetFeedbackMode('vibration'),
    'vibration feedback only': const SetFeedbackMode('vibration'),
    'change feedback mode to both': const SetFeedbackMode('both'),
    'set feedback mode to both': const SetFeedbackMode('both'),
    'use audio and vibration feedback': const SetFeedbackMode('both'),
  };

  // ─────────── Context-Dependent Aliases ────────────────────────

  static final _contextualAliases =
      <VoiceFeatureContext, Map<String, VoiceIntent>>{
        // In Mobile Detection, bare "stop" means stop detection.
        VoiceFeatureContext.mobileDetection: {
          'stop': const StopMobileDetection(),
          'stop it': const StopMobileDetection(),
          'pause': const PauseMobileDetection(),
          'resume': const ResumeMobileDetection(),
          'continue': const ResumeMobileDetection(),
        },
        // In Scanner reading, bare contextual commands map cleanly.
        VoiceFeatureContext.scannerReading: {
          'stop': const Silence(),
          'stop it': const Silence(),
          'quiet': const Silence(),
          'silence': const Silence(),
          'pause': const ReadingPause(),
          'hold': const ReadingPause(),
          'hold on': const ReadingPause(),
          'resume': const ReadingResume(),
          'start': const ReadingResume(),
          'continue': const ReadingResume(),
          'play': const ReadingResume(),
          'go on': const ReadingResume(),
          'next': const ReadingNext(),
          'previous': const ReadingPrevious(),
          'back': const ReadingPrevious(),
          'go back': const ReadingPrevious(),
          'repeat': const ReadingRepeat(),
          'again': const ReadingRepeat(),
          'restart': const ReadingRestart(),
          'spell': const ReadingSpell(),
          'slow down': const SetReadingProfile('learning'),
          'speed up': const SetReadingProfile('skim'),
          'copy': const CopyScannedText(),
          'rescan': const RescanDocument(),
          'scan again': const RescanDocument(),
          'new scan': const RescanDocument(),
        },
        // In Scanner capture, bare verbs map to capture/camera actions.
        VoiceFeatureContext.scannerCapture: {
          'scan': const ScanDocument(),
          'capture': const ScanDocument(),
          'photo': const ScanDocument(),
          'picture': const ScanDocument(),
          'take photo': const ScanDocument(),
          'take picture': const ScanDocument(),
          'close scanner': const NavigateBack(),
          'exit scanner': const NavigateBack(),
          'close': const NavigateBack(),
          'exit': const NavigateBack(),
        },
      };

  // ─────────── Conversation Patterns ────────────────────────────

  static final _conversationPatterns = <String, VoiceIntent>{
    'what can you do': const WhatCanYouDo(),
    'how can you help': const WhatCanYouDo(),
    'available commands': const WhatCanYouDo(),
    'voice commands': const WhatCanYouDo(),
    'list commands': const WhatCanYouDo(),

    'who are you': const WhoAreYou(),
    'what are you': const WhoAreYou(),
    'your name': const WhoAreYou(),

    'goodbye': const DismissAssistant(),
    'good bye': const DismissAssistant(),
    'bye': const DismissAssistant(),
    'by': const DismissAssistant(),
    'dismiss': const DismissAssistant(),
    'stop listening': const DismissAssistant(),
    'go to sleep': const DismissAssistant(),
    'sleep': const DismissAssistant(),
    "that's all": const DismissAssistant(),
    'that is all': const DismissAssistant(),
    'exit assistant': const DismissAssistant(),
    'dismiss assistant': const DismissAssistant(),

    'thank you': const ThankYou(),
    'thanks': const ThankYou(),

    'hello': const Greeting(),
    'how are you': const Greeting(),
  };
}

extension on VoiceCommand {
  VoiceCommand _withTranscripts(String original, String normalized) =>
      VoiceCommand(
        intent: intent,
        matchScore: matchScore,
        matchType: matchType,
        slots: slots,
        alternatives: alternatives,
        originalTranscript: original,
        normalizedTranscript: normalized,
      );
}
