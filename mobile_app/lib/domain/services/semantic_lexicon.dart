/// Semantic concept normalization for voice intent resolution.
///
/// Maps natural language verbs and entities to canonical semantic tokens.
/// This enables composition-based intent matching: ACTIVATE + MOBILE_DETECTION
/// → StartMobileDetection, without needing to enumerate every phrase variant.
abstract final class SemanticLexicon {
  // ─────────────────── Verb Normalization ────────────────────────

  /// Maps natural language verbs/phrases to canonical action tokens.
  static const Map<String, String> verbMap = {
    // ACTIVATE
    'start': 'ACTIVATE',
    'begin': 'ACTIVATE',
    'run': 'ACTIVATE',
    'turn on': 'ACTIVATE',
    'switch on': 'ACTIVATE',
    'enable': 'ACTIVATE',
    'activate': 'ACTIVATE',
    'launch': 'ACTIVATE',
    'initiate': 'ACTIVATE',

    // DEACTIVATE
    'stop': 'DEACTIVATE',
    'end': 'DEACTIVATE',
    'turn off': 'DEACTIVATE',
    'switch off': 'DEACTIVATE',
    'disable': 'DEACTIVATE',
    'deactivate': 'DEACTIVATE',
    'close': 'DEACTIVATE',
    'shut down': 'DEACTIVATE',
    'kill': 'DEACTIVATE',
    'exit': 'DEACTIVATE',
    'quit': 'DEACTIVATE',

    // PAUSE
    'pause': 'PAUSE',
    'hold': 'PAUSE',
    'hold on': 'PAUSE',
    'suspend': 'PAUSE',
    'freeze': 'PAUSE',

    // RESUME
    'resume': 'RESUME',
    'continue': 'RESUME',
    'unpause': 'RESUME',
    'go on': 'RESUME',
    'carry on': 'RESUME',
    'keep going': 'RESUME',

    // NAVIGATE
    'go to': 'NAVIGATE',
    'navigate to': 'NAVIGATE',
    'show': 'NAVIGATE',
    'open': 'NAVIGATE',
    'go': 'NAVIGATE',

    // QUERY
    'check': 'QUERY',
    'status': 'QUERY',
    'what is': 'QUERY',
    "what's": 'QUERY',
    'tell me': 'QUERY',
    'how is': 'QUERY',
    'is it': 'QUERY',
    'read': 'QUERY',

    // SET
    'set': 'SET',
    'change': 'SET',
    'adjust': 'SET',
    'switch to': 'SET',
    'make': 'SET',

    // INCREASE
    'increase': 'INCREASE',
    'raise': 'INCREASE',
    'boost': 'INCREASE',
    'more': 'INCREASE',
    'higher': 'INCREASE',

    // DECREASE
    'decrease': 'DECREASE',
    'reduce': 'DECREASE',
    'lower': 'DECREASE',
    'less': 'DECREASE',

    // SCAN
    'scan': 'SCAN',
    'capture': 'SCAN',
    'take picture': 'SCAN',
    'take photo': 'SCAN',
    'take a picture': 'SCAN',
    'take a photo': 'SCAN',
    'photograph': 'SCAN',
    'snap': 'SCAN',

    // CONNECT
    'connect': 'CONNECT',
    'pair': 'CONNECT',
    'link': 'CONNECT',
    'reconnect': 'CONNECT',

    // DISCONNECT
    'disconnect': 'DISCONNECT',
    'unpair': 'DISCONNECT',
    'unlink': 'DISCONNECT',

    // DISCOVER
    'discover': 'DISCOVER',
    'find': 'DISCOVER',
    'search': 'DISCOVER',
    'look for': 'DISCOVER',
    'detect': 'DISCOVER',
  };

  // ─────────────────── Entity Normalization ──────────────────────

  /// Maps natural language nouns/phrases to canonical entity tokens.
  static const Map<String, String> entityMap = {
    // MOBILE_DETECTION
    'mobile mode': 'MOBILE_DETECTION',
    'mobile detection': 'MOBILE_DETECTION',
    'mobile assistance': 'MOBILE_DETECTION',
    'phone mode': 'MOBILE_DETECTION',
    'phone detection': 'MOBILE_DETECTION',
    'object detection': 'MOBILE_DETECTION',
    'obstacle detection': 'MOBILE_DETECTION',
    'detection': 'MOBILE_DETECTION',
    'camera': 'MOBILE_DETECTION',
    'vision': 'MOBILE_DETECTION',
    'seeing': 'MOBILE_DETECTION',
    'assistance': 'MOBILE_DETECTION',
    'mobile': 'MOBILE_DETECTION',

    // SCANNER
    'scanner': 'SCANNER',
    'document scanner': 'SCANNER',
    'document': 'SCANNER',
    'ocr': 'SCANNER',
    'reader': 'SCANNER',
    'ocr scanner': 'SCANNER',
    'text scanner': 'SCANNER',

    // RASPBERRY_PI
    'raspberry pi': 'RASPBERRY_PI',
    'raspberry': 'RASPBERRY_PI',
    'wearable': 'RASPBERRY_PI',
    'smart cap': 'RASPBERRY_PI',
    'pi': 'RASPBERRY_PI',
    'cap': 'RASPBERRY_PI',
    'wearable mode': 'RASPBERRY_PI',
    'pi mode': 'RASPBERRY_PI',

    // SETTINGS
    'settings': 'SETTINGS',
    'preferences': 'SETTINGS',
    'options': 'SETTINGS',
    'configuration': 'SETTINGS',

    // HOME
    'home': 'HOME',
    'main screen': 'HOME',
    'home screen': 'HOME',

    // SMART_AI
    'smart ai': 'SMART_AI',
    'ai assistant': 'SMART_AI',
    'online assistant': 'SMART_AI',
    'assistant': 'SMART_AI',
    'ai chat': 'SMART_AI',
    'ai': 'SMART_AI',

    // MODES
    'modes': 'MODES',
    'mode selection': 'MODES',
    'mode': 'MODES',

    // SAFETY
    'safety': 'SAFETY',
    'safety information': 'SAFETY',
    'about safety': 'SAFETY',

    // HELP
    'help': 'HELP',
    'user guide': 'HELP',
    'guide': 'HELP',
    'instructions': 'HELP',

    // SENSITIVITY
    'sensitivity': 'SENSITIVITY',
    'confidence': 'SENSITIVITY',
    'accuracy': 'SENSITIVITY',
    'detection level': 'SENSITIVITY',
    'detection threshold': 'SENSITIVITY',

    // FEEDBACK
    'feedback': 'FEEDBACK',
    'feedback mode': 'FEEDBACK',

    // FLASHLIGHT
    'flashlight': 'FLASHLIGHT',
    'torch': 'FLASHLIGHT',
    'light': 'FLASHLIGHT',

    // TIME
    'time': 'TIME',
    'clock': 'TIME',

    // DATE
    'date': 'DATE',
    'day': 'DATE',
    'today': 'DATE',

    // BATTERY
    'battery': 'BATTERY',
    'battery level': 'BATTERY',
    'battery status': 'BATTERY',
    'charge': 'BATTERY',

    // HANDS_FREE
    'hands free': 'HANDS_FREE',
    'hands-free': 'HANDS_FREE',
    'wake word': 'HANDS_FREE',
    'voice activation': 'HANDS_FREE',

    // READING
    'reading': 'READING',
    'speech': 'READING',
    'audio': 'READING',
    'voice': 'READING',
    'speaking': 'READING',

    // ENVIRONMENT
    'indoor': 'INDOOR',
    'indoor mode': 'INDOOR',
    'home mode': 'INDOOR',
    'outdoor': 'OUTDOOR',
    'outdoor mode': 'OUTDOOR',
    'street mode': 'OUTDOOR',
  };

  /// Normalizes raw text by extracting the longest matching verb.
  static String? extractVerb(String text) {
    // Try longest phrases first for accuracy.
    final sorted = verbMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sorted) {
      if (text.contains(phrase)) {
        return verbMap[phrase];
      }
    }
    return null;
  }

  /// Normalizes raw text by extracting the longest matching entity.
  static String? extractEntity(String text) {
    final sorted = entityMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sorted) {
      if (text.contains(phrase)) {
        return entityMap[phrase];
      }
    }
    return null;
  }

  /// Extracts all matching entities from text, ordered by match position.
  static List<String> extractAllEntities(String text) {
    final sorted = entityMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final found = <String>[];
    final usedRanges = <(int, int)>[];

    for (final phrase in sorted) {
      final index = text.indexOf(phrase);
      if (index < 0) continue;
      final end = index + phrase.length;
      final overlaps = usedRanges.any(
        (range) => index < range.$2 && end > range.$1,
      );
      if (overlaps) continue;
      found.add(entityMap[phrase]!);
      usedRanges.add((index, end));
    }
    return found;
  }
}
