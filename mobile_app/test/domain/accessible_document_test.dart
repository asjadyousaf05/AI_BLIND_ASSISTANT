import 'package:ai_blind_assistant/domain/entities/accessible_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessibleDocument Model', () {
    test('constructs correctly and provides word and sentence lookups', () {
      const word1 = AccessibleWord(
        id: 'w1',
        text: 'Hello',
        sentenceStart: 0,
        sentenceEnd: 5,
        documentStart: 0,
        documentEnd: 5,
      );
      const word2 = AccessibleWord(
        id: 'w2',
        text: 'world',
        sentenceStart: 6,
        sentenceEnd: 11,
        documentStart: 6,
        documentEnd: 11,
      );

      const sentence1 = AccessibleSentence(
        id: 's1',
        index: 0,
        text: 'Hello world.',
        normalizedStart: 0,
        normalizedEnd: 12,
        words: [word1, word2],
      );

      const paragraph = AccessibleParagraph(
        id: 'p1',
        index: 0,
        sentences: [sentence1],
      );

      const document = AccessibleDocument(
        id: 'doc_1',
        rawOcrText: 'Hello world.',
        normalizedText: 'Hello world.',
        paragraphs: [paragraph],
        sentences: [sentence1],
        totalWords: 2,
      );

      expect(document.isNotEmpty, isTrue);
      expect(document.sentenceCount, 1);
      expect(document.totalWords, 2);
      expect(document.sentenceAt(0), sentence1);
      expect(sentence1.wordAtSentenceOffset(2), word1);
      expect(sentence1.wordAtSentenceOffset(8), word2);
      expect(sentence1.wordAtSentenceOffset(20), isNull);
    });

    test('empty document behavior', () {
      expect(AccessibleDocument.empty.isEmpty, isTrue);
      expect(AccessibleDocument.empty.sentences, isEmpty);
      expect(AccessibleDocument.empty.totalWords, 0);
    });
  });
}
