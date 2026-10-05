import 'dart:typed_data';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/sanitize.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';
import 'book_importer.dart';
import 'text_decoding.dart';

/// Plain text. Detects chapters from Markdown-style "# Title" headings or
/// conventional headings such as "CHAPTER IV" / "Chapter 12: The Return".
class TxtImporter implements BookImporter {
  const TxtImporter();

  static final RegExp _markdownHeading = RegExp(r'^#{1,3}\s+(.+)$');
  static const String _numberWords =
      'one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|'
      'fifteen|sixteen|seventeen|eighteen|nineteen|twenty|first|second|third|fourth|fifth|'
      'sixth|seventh|eighth|ninth|tenth|eleventh|twelfth|last|final';
  static final RegExp _numberedHeading = RegExp(
    '^(chapter|book|part|letter|section|volume)\\s+([0-9]{1,4}|[ivxlc]{1,7}|$_numberWords)\\b\\.?(.{0,60})\$',
    caseSensitive: false,
  );
  static final RegExp _standaloneHeading = RegExp(
    r'^(prologue|epilogue|introduction|preface|foreword|afterword)\b\.?(\s*[:.\-–—]\s*.{0,60})?$',
    caseSensitive: false,
  );
  static final RegExp _leadingSeparators = RegExp(r'^[\s:.\-–—]+');
  static const int _maxHeadingLength = 80;

  /// When less than one in this many lines is blank, assume one paragraph per
  /// line rather than blank-line separated paragraphs.
  static const int _sparseBlankRatio = 25;

  @override
  Set<String> get extensions => const {'txt', 'text', 'md'};

  @override
  BookFormat get format => BookFormat.txt;

  @override
  bool get isAvailable => true;

  @override
  ParsedBook parse(Uint8List bytes, {required String fileName}) {
    final text = normaliseLineEndings(decodeText(bytes));
    final chapters = parseText(text);
    if (chapters.isEmpty) throw const ImportException(ImportErrorType.emptyBook);
    return ParsedBook(
      title: Sanitize.line(titleFromFileName(fileName), maxLength: ImportConstants.maxTitleLength),
      author: '',
      chapters: chapters,
    );
  }

  static List<ParsedChapter> parseText(String text) {
    final lines = text.split('\n');
    final blankLines = lines.where((l) => l.trim().isEmpty).length;
    final linePerParagraph = blankLines * _sparseBlankRatio < lines.length;

    final chapters = <ParsedChapter>[];
    var title = 'Beginning';
    var paragraphs = <String>[];
    final buffer = <String>[];

    void flushParagraph() {
      if (buffer.isEmpty) return;
      final paragraph = Sanitize.text(buffer.join(' '));
      if (paragraph.isNotEmpty) paragraphs.add(paragraph);
      buffer.clear();
    }

    void flushChapter() {
      flushParagraph();
      if (paragraphs.isNotEmpty) {
        chapters.add(ParsedChapter(title: title, paragraphs: paragraphs));
      }
      paragraphs = <String>[];
    }

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      final heading = _headingFor(trimmed, previousBlank: i == 0 || lines[i - 1].trim().isEmpty);
      if (heading != null) {
        flushChapter();
        title = Sanitize.line(heading, maxLength: ImportConstants.maxChapterTitleLength);
        continue;
      }
      if (trimmed.isEmpty) {
        flushParagraph();
      } else {
        buffer.add(trimmed);
        if (linePerParagraph) flushParagraph();
      }
    }
    flushChapter();

    if (chapters.length == 1 && chapters.first.title == 'Beginning') {
      return [chapters.first.copyWith(title: 'Full text')];
    }
    return chapters;
  }

  static String? _headingFor(String line, {required bool previousBlank}) {
    if (line.isEmpty || line.length > _maxHeadingLength) return null;
    final markdown = _markdownHeading.firstMatch(line);
    if (markdown != null) return markdown.group(1)!.trim();
    if (!previousBlank) return null;
    if (_standaloneHeading.hasMatch(line)) return line.replaceAll(RegExp(r'[.]+$'), '');
    final numbered = _numberedHeading.firstMatch(line);
    if (numbered == null) return null;
    // "Chapter 3: The Return" is a heading; "Part two of the plan was…" is prose.
    final rest = numbered.group(3)!.replaceFirst(_leadingSeparators, '');
    if (rest.isNotEmpty && rest[0] != rest[0].toUpperCase()) return null;
    return line.replaceAll(RegExp(r'[.]+$'), '');
  }
}
