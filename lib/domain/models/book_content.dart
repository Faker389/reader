import 'dart:typed_data';

import '../../core/utils/json.dart';

/// Bit flags describing the punctuation context of each word. Computed once
/// at load time so the reading engine does no string inspection per tick.
abstract final class WordFlags {
  static const int clauseEnd = 1;
  static const int sentenceEnd = 1 << 1;
  static const int paragraphEnd = 1 << 2;
  static const int chapterStart = 1 << 3;
}

class ChapterMarker {
  const ChapterMarker({required this.title, required this.startIndex});

  final String title;
  final int startIndex;
}

/// Tokenised, ready-to-read book text. Words are stored in a flat list with a
/// parallel flag array so a book of several hundred thousand words stays
/// compact and random access is O(1).
class BookContent {
  BookContent({
    required this.words,
    required this.flags,
    required this.chapters,
  }) : assert(words.length == flags.length);

  final List<String> words;
  final Uint8List flags;
  final List<ChapterMarker> chapters;

  int get length => words.length;
  bool get isEmpty => words.isEmpty;

  /// Index of the chapter containing [wordIndex] (binary search).
  int chapterIndexAt(int wordIndex) {
    if (chapters.isEmpty) return 0;
    var low = 0;
    var high = chapters.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (chapters[mid].startIndex <= wordIndex) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  int chapterEnd(int chapterIndex) => chapterIndex + 1 < chapters.length
      ? chapters[chapterIndex + 1].startIndex
      : words.length;

  int chapterWordCount(int chapterIndex) =>
      chapterEnd(chapterIndex) - chapters[chapterIndex].startIndex;

  bool isChapterStart(int wordIndex) =>
      wordIndex < flags.length && flags[wordIndex] & WordFlags.chapterStart != 0;

  /// Start of the sentence containing [wordIndex].
  int sentenceStart(int wordIndex) {
    var i = wordIndex - 1;
    while (i >= 0) {
      if (flags[i] & (WordFlags.sentenceEnd | WordFlags.paragraphEnd) != 0) break;
      i--;
    }
    return i + 1;
  }
}

class ParsedChapter {
  const ParsedChapter({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  int get wordCount {
    var count = 0;
    for (final paragraph in paragraphs) {
      count += _countWords(paragraph);
    }
    return count;
  }

  ParsedChapter copyWith({String? title, List<String>? paragraphs}) =>
      ParsedChapter(title: title ?? this.title, paragraphs: paragraphs ?? this.paragraphs);

  JsonMap toJson() => {'t': title, 'p': paragraphs};

  factory ParsedChapter.fromJson(JsonMap json) =>
      ParsedChapter(title: json.str('t'), paragraphs: json.stringList('p'));

  static int _countWords(String text) {
    var count = 0;
    var inWord = false;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      final isSpace = c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D || c == 0xA0;
      if (isSpace) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        count++;
      }
    }
    return count;
  }
}

/// Output of any importer: structured, plain text plus optional metadata.
class ParsedBook {
  const ParsedBook({
    required this.title,
    required this.author,
    required this.chapters,
    this.coverBytes,
    this.coverExtension,
  });

  final String title;
  final String author;
  final List<ParsedChapter> chapters;
  final Uint8List? coverBytes;
  final String? coverExtension;

  int get wordCount => chapters.fold(0, (sum, c) => sum + c.wordCount);

  ParsedBook copyWith({
    String? title,
    String? author,
    List<ParsedChapter>? chapters,
    Uint8List? coverBytes,
    String? coverExtension,
  }) =>
      ParsedBook(
        title: title ?? this.title,
        author: author ?? this.author,
        chapters: chapters ?? this.chapters,
        coverBytes: coverBytes ?? this.coverBytes,
        coverExtension: coverExtension ?? this.coverExtension,
      );

  /// Serialised form stored on disk. Only text, no binary data.
  JsonMap toContentJson() => {
        'v': 1,
        'chapters': [for (final chapter in chapters) chapter.toJson()],
      };

  static List<ParsedChapter> chaptersFromContentJson(JsonMap json) =>
      [for (final c in json.mapList('chapters')) ParsedChapter.fromJson(c)];
}
