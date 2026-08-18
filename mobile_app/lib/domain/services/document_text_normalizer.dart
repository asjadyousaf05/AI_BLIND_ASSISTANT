import '../entities/accessible_document.dart';

/// NLP-grade text normalization and tokenization pipeline for OCR text.
class DocumentTextNormalizer {
  const DocumentTextNormalizer._();

  static const _placeholderDot = '\uE000';

  static const _commonAbbreviations = [
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'rev',
    'sr',
    'jr',
    'st',
    'no',
    'e.g',
    'i.e',
    'vs',
    'etc',
    'al',
    'approx',
    'inc',
    'corp',
    'ltd',
    'co',
    'fig',
    'vol',
    'dept',
    'est',
    'jan',
    'feb',
    'mar',
    'apr',
    'jun',
    'jul',
    'aug',
    'sept',
    'sep',
    'oct',
    'nov',
    'dec',
    'a.m',
    'p.m',
    'u.s',
    'u.k',
  ];

  /// Converts raw OCR string into a structured, fully indexed [AccessibleDocument].
  static AccessibleDocument normalize(String rawOcrText, {String? documentId}) {
    final rawCleaned = rawOcrText.trim();
    final docId = documentId ?? 'doc_${DateTime.now().millisecondsSinceEpoch}';
    if (rawCleaned.isEmpty) {
      return AccessibleDocument(
        id: docId,
        rawOcrText: rawOcrText,
        normalizedText: '',
        paragraphs: const [],
        sentences: const [],
        totalWords: 0,
      );
    }

    // 1. Normalize line endings
    var text = rawCleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Rejoin OCR hyphenated line wraps (e.g. "medica-\ntion" -> "medication")
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z]{2,})-\n([A-Za-z]{2,})'),
      (m) => '${m[1]}${m[2]}',
    );

    // 3. Protect decimals & currency (e.g. 3.14, $19.99, 2.5 mg, 1.5%)
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\.(\d+)'),
      (m) => '${m[1]}$_placeholderDot${m[2]}',
    );

    // 4. Protect common abbreviations
    for (final abbr in _commonAbbreviations) {
      text = text.replaceAllMapped(
        RegExp(r'\b(' + RegExp.escape(abbr) + r')\.', caseSensitive: false),
        (m) => '${m[1]}$_placeholderDot',
      );
    }

    // 5. Protect single-letter initials (e.g. "J. Smith", "A. B. Carter", "U.S.A.")
    text = text.replaceAllMapped(
      RegExp(r'\b([A-Za-z])\.'),
      (m) => '${m[1]}$_placeholderDot',
    );

    // 6. Segment into structural paragraphs based on double newlines and list headers
    final rawLines = text.split('\n');
    final paragraphBuffers = <StringBuffer>[];
    StringBuffer? currentPara;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) {
        currentPara = null;
        continue;
      }

      final isListHeader = RegExp(r'^(\d+[\.\)]|[•\-\*])\s+').hasMatch(line);
      if (currentPara == null || isListHeader) {
        currentPara = StringBuffer(line);
        paragraphBuffers.add(currentPara);
      } else {
        final lastStr = currentPara.toString().trimRight();
        final endsWithTerminal =
            lastStr.endsWith('.') ||
            lastStr.endsWith('!') ||
            lastStr.endsWith('?') ||
            lastStr.endsWith(':') ||
            lastStr.endsWith(';');
        if (endsWithTerminal) {
          currentPara = StringBuffer(line);
          paragraphBuffers.add(currentPara);
        } else {
          // Soft line-wrap continuation: join with space
          currentPara.write(' $line');
        }
      }
    }

    final allSentences = <AccessibleSentence>[];
    final allParagraphs = <AccessibleParagraph>[];
    final fullDocBuffer = StringBuffer();
    int sentenceGlobalIndex = 0;

    for (int pIdx = 0; pIdx < paragraphBuffers.length; pIdx++) {
      final paraText = paragraphBuffers[pIdx].toString();
      final paraChunks = paraText
          .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9"“\(\[•\-\*]|\b)'))
          .map((s) => s.replaceAll(_placeholderDot, '.').trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);

      if (paraChunks.isEmpty) continue;

      final paraSentences = <AccessibleSentence>[];

      for (int sIdx = 0; sIdx < paraChunks.length; sIdx++) {
        final sentenceText = paraChunks[sIdx];
        if (sIdx > 0 || pIdx > 0) fullDocBuffer.write(' ');
        final normalizedStart = fullDocBuffer.length;
        fullDocBuffer.write(sentenceText);
        final normalizedEnd = fullDocBuffer.length;

        // Tokenize words
        final wordTokens = <AccessibleWord>[];
        final rawWords = sentenceText.split(RegExp(r'\s+'));
        int currentSentenceWordOffset = 0;

        for (int wIdx = 0; wIdx < rawWords.length; wIdx++) {
          final wordStr = rawWords[wIdx].trim();
          if (wordStr.isEmpty) continue;

          final wStartInSent = sentenceText.indexOf(
            wordStr,
            currentSentenceWordOffset,
          );
          final wEndInSent = wStartInSent + wordStr.length;
          currentSentenceWordOffset = wEndInSent;

          final wStartInDoc = normalizedStart + wStartInSent;
          final wEndInDoc = normalizedStart + wEndInSent;

          wordTokens.add(
            AccessibleWord(
              id: '${docId}_s${sentenceGlobalIndex}_w$wIdx',
              text: wordStr,
              sentenceStart: wStartInSent,
              sentenceEnd: wEndInSent,
              documentStart: wStartInDoc,
              documentEnd: wEndInDoc,
            ),
          );
        }

        final sentence = AccessibleSentence(
          id: '${docId}_sent_$sentenceGlobalIndex',
          index: sentenceGlobalIndex,
          text: sentenceText,
          normalizedStart: normalizedStart,
          normalizedEnd: normalizedEnd,
          words: List.unmodifiable(wordTokens),
        );

        allSentences.add(sentence);
        paraSentences.add(sentence);
        sentenceGlobalIndex++;
      }

      allParagraphs.add(
        AccessibleParagraph(
          id: '${docId}_para_$pIdx',
          index: pIdx,
          sentences: List.unmodifiable(paraSentences),
        ),
      );
    }

    final totalWords = allSentences.fold(0, (sum, s) => sum + s.wordCount);

    return AccessibleDocument(
      id: docId,
      rawOcrText: rawOcrText,
      normalizedText: fullDocBuffer.toString(),
      paragraphs: List.unmodifiable(allParagraphs),
      sentences: List.unmodifiable(allSentences),
      totalWords: totalWords,
    );
  }
}
