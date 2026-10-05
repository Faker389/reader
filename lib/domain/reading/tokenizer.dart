import 'dart:typed_data';

import '../models/book_content.dart';

/// Turns structured paragraphs into the flat word list used by the reader.
///
/// Designed to run inside an isolate: it is pure, synchronous and allocates
/// only the output collections.
abstract final class Tokenizer {
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Em/en dashes glued between words ("mind—and") are split so that each
  /// side is displayed separately, with the dash kept on the first word.
  static final RegExp _dashJoin = RegExp(r'(?<=\S)(—|–|--)(?=\S)');

  static const Set<String> _abbreviations = {
    'mr.', 'mrs.', 'ms.', 'dr.', 'st.', 'jr.', 'sr.', 'vs.', 'etc.', 'e.g.', 'i.e.',
    'mt.', 'no.', 'prof.', 'capt.', 'col.', 'gen.', 'lt.', 'rev.',
  };

  static const String _trailingClosers = '"\'”’)]}»›*';

  static BookContent tokenize(List<ParsedChapter> chapters) {
    final words = <String>[];
    final pendingFlags = <int>[];
    final markers = <ChapterMarker>[];

    for (final chapter in chapters) {
      final chapterStart = words.length;
      var chapterHasWords = false;
      for (final paragraph in chapter.paragraphs) {
        final tokens = _split(paragraph);
        if (tokens.isEmpty) continue;
        for (var i = 0; i < tokens.length; i++) {
          final token = tokens[i];
          var flags = flagsFor(token);
          if (i == tokens.length - 1) flags |= WordFlags.paragraphEnd;
          if (!chapterHasWords) {
            flags |= WordFlags.chapterStart;
            chapterHasWords = true;
          }
          words.add(token);
          pendingFlags.add(flags);
        }
      }
      if (chapterHasWords) {
        markers.add(ChapterMarker(title: chapter.title, startIndex: chapterStart));
      }
    }

    return BookContent(
      words: List<String>.unmodifiable(words),
      flags: Uint8List.fromList(pendingFlags),
      chapters: List<ChapterMarker>.unmodifiable(markers),
    );
  }

  static List<String> _split(String paragraph) {
    final normalised = paragraph.replaceAllMapped(_dashJoin, (m) => '${m[1]} ');
    return [
      for (final token in normalised.split(_whitespace))
        if (token.isNotEmpty) token,
    ];
  }

  static int flagsFor(String token) {
    var end = token.length;
    while (end > 0 && _trailingClosers.contains(token[end - 1])) {
      end--;
    }
    if (end == 0) return 0;
    final last = token[end - 1];
    if (last == '.' || last == '!' || last == '?' || last == '…') {
      if (last == '.' && _abbreviations.contains(token.substring(0, end).toLowerCase())) {
        return 0;
      }
      return WordFlags.sentenceEnd;
    }
    if (last == ',' || last == ';' || last == ':' || last == '—' || last == '–' || last == '-') {
      return WordFlags.clauseEnd;
    }
    return 0;
  }
}
