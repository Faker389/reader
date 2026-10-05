import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/sanitize.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';
import 'book_importer.dart';
import 'text_decoding.dart';

class CsvInspection {
  const CsvInspection({
    required this.columns,
    required this.previewRows,
    required this.hasHeader,
    required this.suggestedColumn,
    required this.rowCount,
  });

  /// Column names (from the header row, or "Column N").
  final List<String> columns;
  final List<List<String>> previewRows;
  final bool hasHeader;
  final int suggestedColumn;
  final int rowCount;

  bool get needsColumnChoice => columns.length > 1;
}

/// CSV with one text value per row — either single words or sentences and
/// paragraphs. When there are several columns the user chooses which one
/// holds the text.
class CsvImporter implements BookImporter {
  const CsvImporter();

  static const Set<String> _headerHints = {'text', 'word', 'words', 'sentence', 'paragraph', 'content', 'body'};

  @override
  Set<String> get extensions => const {'csv', 'tsv'};

  @override
  BookFormat get format => BookFormat.csv;

  @override
  bool get isAvailable => true;

  @override
  ParsedBook parse(Uint8List bytes, {required String fileName}) {
    final inspection = inspect(bytes);
    return parseColumn(
      bytes,
      fileName: fileName,
      column: inspection.suggestedColumn,
      hasHeader: inspection.hasHeader,
    );
  }

  CsvInspection inspect(Uint8List bytes) {
    final rows = _rows(bytes);
    if (rows.isEmpty) throw const ImportException(ImportErrorType.emptyBook);
    final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
    final first = rows.first;
    final hasHeader = width > 0 && _looksLikeHeader(first, rows.skip(1).take(20).toList());
    final columns = [
      for (var i = 0; i < width; i++)
        hasHeader && i < first.length && first[i].trim().isNotEmpty ? first[i].trim() : 'Column ${i + 1}',
    ];
    final body = hasHeader ? rows.skip(1).toList() : rows;
    return CsvInspection(
      columns: columns,
      previewRows: body.take(ImportConstants.csvPreviewRows).toList(),
      hasHeader: hasHeader,
      suggestedColumn: _suggestColumn(columns, body, width),
      rowCount: body.length,
    );
  }

  ParsedBook parseColumn(
    Uint8List bytes, {
    required String fileName,
    required int column,
    required bool hasHeader,
  }) {
    final rows = _rows(bytes);
    final body = hasHeader ? rows.skip(1) : rows;
    final values = <String>[
      for (final row in body)
        if (column < row.length && Sanitize.text(row[column]).isNotEmpty) Sanitize.text(row[column]),
    ];
    if (values.isEmpty) throw const ImportException(ImportErrorType.noTextColumn);

    final singleWords = values.where((v) => !v.contains(' ')).length > values.length * 0.8;
    final paragraphs = singleWords ? _groupWords(values) : values;
    return ParsedBook(
      title: Sanitize.line(titleFromFileName(fileName), maxLength: ImportConstants.maxTitleLength),
      author: '',
      chapters: [ParsedChapter(title: 'Full text', paragraphs: paragraphs)],
    );
  }

  List<String> _groupWords(List<String> words) {
    final paragraphs = <String>[];
    for (var i = 0; i < words.length; i += ImportConstants.csvWordsPerParagraph) {
      final end = (i + ImportConstants.csvWordsPerParagraph).clamp(0, words.length);
      paragraphs.add(words.sublist(i, end).join(' '));
    }
    return paragraphs;
  }

  List<List<String>> _rows(Uint8List bytes) {
    final text = normaliseLineEndings(decodeText(bytes));
    if (text.trim().isEmpty) return const [];
    final delimiter = _detectDelimiter(text);
    try {
      final parsed = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert<dynamic>(text);
      return [
        for (final row in parsed)
          if (row.any((cell) => cell.toString().trim().isNotEmpty))
            [for (final cell in row) cell.toString()],
      ];
    } on Object catch (e) {
      throw ImportException(ImportErrorType.corruptedFile, '$e');
    }
  }

  String _detectDelimiter(String text) {
    final sample = text.length > 4000 ? text.substring(0, 4000) : text;
    const candidates = [',', ';', '\t', '|'];
    var best = ',';
    var bestCount = -1;
    for (final c in candidates) {
      final count = c.allMatches(sample).length;
      if (count > bestCount) {
        best = c;
        bestCount = count;
      }
    }
    return best;
  }

  bool _looksLikeHeader(List<String> first, List<List<String>> sample) {
    if (first.any((c) => _headerHints.contains(c.trim().toLowerCase()))) return true;
    if (sample.isEmpty) return false;
    // Headers tend to be short compared with the values below them.
    final firstLength = first.fold<int>(0, (s, c) => s + c.length) / first.length;
    final avgLength = sample.fold<double>(
          0,
          (s, r) => s + (r.isEmpty ? 0 : r.fold<int>(0, (a, c) => a + c.length) / r.length),
        ) /
        sample.length;
    return first.length > 1 && firstLength < avgLength * 0.5;
  }

  int _suggestColumn(List<String> columns, List<List<String>> body, int width) {
    for (var i = 0; i < columns.length; i++) {
      if (_headerHints.contains(columns[i].toLowerCase())) return i;
    }
    var best = 0;
    var bestScore = -1.0;
    final sample = body.take(50).toList();
    for (var i = 0; i < width; i++) {
      var letters = 0;
      for (final row in sample) {
        if (i >= row.length) continue;
        letters += RegExp(r'[A-Za-zÀ-ž]').allMatches(row[i]).length;
      }
      if (letters > bestScore) {
        best = i;
        bestScore = letters.toDouble();
      }
    }
    return best;
  }
}
