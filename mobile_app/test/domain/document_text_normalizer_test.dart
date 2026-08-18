import 'package:ai_blind_assistant/domain/services/document_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentTextNormalizer', () {
    test(
      'protects honorifics, abbreviations, and initials without false splits',
      () {
        const input = 'Dr. Smith and Mr. Jones met at 8 a.m. with Prof. Davis.';
        final doc = DocumentTextNormalizer.normalize(input);

        expect(doc.sentences.length, 1);
        expect(
          doc.sentences.first.text,
          'Dr. Smith and Mr. Jones met at 8 a.m. with Prof. Davis.',
        );
      },
    );

    test('protects decimals, currency, and dosages', () {
      const input =
          'Prescription is 2.5 mg. The cost is \$19.99 for 3.14 liters.';
      final doc = DocumentTextNormalizer.normalize(input);

      expect(doc.sentences.length, 2);
      expect(doc.sentences[0].text, 'Prescription is 2.5 mg.');
      expect(doc.sentences[1].text, 'The cost is \$19.99 for 3.14 liters.');
    });

    test('rejoins OCR hyphenated line breaks', () {
      const input = 'Take this medica-\ntion before sleep.';
      final doc = DocumentTextNormalizer.normalize(input);

      expect(doc.sentences.length, 1);
      expect(doc.sentences.first.text, 'Take this medication before sleep.');
    });

    test(
      'merges OCR soft line wraps while preserving grammatical boundaries',
      () {
        const input = '''
Dr. Smith prescribed 2.5 mg of
aspirin. Take once daily after
breakfast. Do not exceed dosage!
''';
        final doc = DocumentTextNormalizer.normalize(input);

        expect(doc.sentences.length, 3);
        expect(
          doc.sentences[0].text,
          'Dr. Smith prescribed 2.5 mg of aspirin.',
        );
        expect(doc.sentences[1].text, 'Take once daily after breakfast.');
        expect(doc.sentences[2].text, 'Do not exceed dosage!');
      },
    );

    test('preserves bullet points and list boundaries', () {
      const input = '''
Warnings:
• Do not exceed dose.
• Keep away from children.
''';
      final doc = DocumentTextNormalizer.normalize(input);

      expect(doc.sentences.length, 3);
      expect(doc.sentences[0].text, 'Warnings:');
      expect(doc.sentences[1].text, '• Do not exceed dose.');
      expect(doc.sentences[2].text, '• Keep away from children.');
    });

    test('generates valid word tokens with accurate sentence offsets', () {
      const input = 'Take 2 tablets.';
      final doc = DocumentTextNormalizer.normalize(input);

      final sent = doc.sentences.first;
      expect(sent.words.length, 3);
      expect(sent.words[0].text, 'Take');
      expect(sent.words[0].sentenceStart, 0);
      expect(sent.words[0].sentenceEnd, 4);

      expect(sent.words[1].text, '2');
      expect(sent.words[2].text, 'tablets.');
    });
  });
}
