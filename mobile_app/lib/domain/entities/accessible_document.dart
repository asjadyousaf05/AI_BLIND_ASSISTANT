import 'package:flutter/foundation.dart';

/// Immutable model representing an individual word token within an accessible document.
@immutable
class AccessibleWord {
  const AccessibleWord({
    required this.id,
    required this.text,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.documentStart,
    required this.documentEnd,
  });

  final String id;
  final String text;
  final int sentenceStart;
  final int sentenceEnd;
  final int documentStart;
  final int documentEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibleWord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          sentenceStart == other.sentenceStart &&
          sentenceEnd == other.sentenceEnd &&
          documentStart == other.documentStart &&
          documentEnd == other.documentEnd;

  @override
  int get hashCode => Object.hash(
    id,
    text,
    sentenceStart,
    sentenceEnd,
    documentStart,
    documentEnd,
  );

  @override
  String toString() =>
      'AccessibleWord(id: $id, text: "$text", sentRange: [$sentenceStart, $sentenceEnd])';
}

/// Immutable model representing a single grammatical sentence in an accessible document.
@immutable
class AccessibleSentence {
  const AccessibleSentence({
    required this.id,
    required this.index,
    required this.text,
    required this.normalizedStart,
    required this.normalizedEnd,
    required this.words,
  });

  final String id;
  final int index;
  final String text;
  final int normalizedStart;
  final int normalizedEnd;
  final List<AccessibleWord> words;

  int get wordCount => words.length;

  /// Finds the word token corresponding to a character offset within the sentence.
  AccessibleWord? wordAtSentenceOffset(int offset) {
    for (final word in words) {
      if (offset >= word.sentenceStart && offset <= word.sentenceEnd) {
        return word;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibleSentence &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          index == other.index &&
          text == other.text &&
          normalizedStart == other.normalizedStart &&
          normalizedEnd == other.normalizedEnd &&
          listEquals(words, other.words);

  @override
  int get hashCode => Object.hash(
    id,
    index,
    text,
    normalizedStart,
    normalizedEnd,
    Object.hashAll(words),
  );

  @override
  String toString() =>
      'AccessibleSentence(id: $id, index: $index, words: ${words.length}, text: "$text")';
}

/// Immutable model representing a structural paragraph in an accessible document.
@immutable
class AccessibleParagraph {
  const AccessibleParagraph({
    required this.id,
    required this.index,
    required this.sentences,
  });

  final String id;
  final int index;
  final List<AccessibleSentence> sentences;

  int get wordCount => sentences.fold(0, (sum, s) => sum + s.wordCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibleParagraph &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          index == other.index &&
          listEquals(sentences, other.sentences);

  @override
  int get hashCode => Object.hash(id, index, Object.hashAll(sentences));

  @override
  String toString() =>
      'AccessibleParagraph(id: $id, index: $index, sentences: ${sentences.length})';
}

/// Immutable, fully structured document model used by the accessible reader.
@immutable
class AccessibleDocument {
  const AccessibleDocument({
    required this.id,
    required this.rawOcrText,
    required this.normalizedText,
    required this.paragraphs,
    required this.sentences,
    required this.totalWords,
  });

  final String id;
  final String rawOcrText;
  final String normalizedText;
  final List<AccessibleParagraph> paragraphs;
  final List<AccessibleSentence> sentences;
  final int totalWords;

  bool get isEmpty => sentences.isEmpty;
  bool get isNotEmpty => sentences.isNotEmpty;
  int get sentenceCount => sentences.length;

  /// Creates an empty document placeholder.
  static const empty = AccessibleDocument(
    id: 'empty_doc',
    rawOcrText: '',
    normalizedText: '',
    paragraphs: [],
    sentences: [],
    totalWords: 0,
  );

  AccessibleSentence? sentenceAt(int index) {
    if (index >= 0 && index < sentences.length) {
      return sentences[index];
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibleDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rawOcrText == other.rawOcrText &&
          normalizedText == other.normalizedText &&
          totalWords == other.totalWords &&
          listEquals(paragraphs, other.paragraphs) &&
          listEquals(sentences, other.sentences);

  @override
  int get hashCode => Object.hash(
    id,
    rawOcrText,
    normalizedText,
    totalWords,
    Object.hashAll(paragraphs),
    Object.hashAll(sentences),
  );

  @override
  String toString() =>
      'AccessibleDocument(id: $id, sentences: ${sentences.length}, words: $totalWords)';
}
