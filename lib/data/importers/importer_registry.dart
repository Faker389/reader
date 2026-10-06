import 'dart:typed_data';

import '../../core/constants/app_constants.dart';
import '../../core/utils/offload.dart';
import '../../core/errors/app_failure.dart';
import '../../domain/models/book_content.dart';
import 'book_importer.dart';
import 'csv_importer.dart';
import 'epub_importer.dart';
import 'pdf_importer.dart';
import 'txt_importer.dart';

/// Picks the importer for a file and runs parsing off the UI isolate.
class ImporterRegistry {
  const ImporterRegistry({
    this.importers = const [TxtImporter(), EpubImporter(), CsvImporter(), PdfImporter()],
  });

  final List<BookImporter> importers;

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  BookImporter forFile(String fileName) {
    final ext = extensionOf(fileName);
    for (final importer in importers) {
      if (importer.extensions.contains(ext)) {
        if (!importer.isAvailable) throw const ImportException(ImportErrorType.plannedFormat);
        return importer;
      }
    }
    throw const ImportException(ImportErrorType.unsupportedFormat);
  }

  bool isCsv(String fileName) => forFile(fileName) is CsvImporter;

  Future<ParsedBook> parse(Uint8List bytes, String fileName) {
    _checkSize(bytes);
    final importer = forFile(fileName);
    return runOffload(() => importer.parse(bytes, fileName: fileName));
  }

  Future<CsvInspection> inspectCsv(Uint8List bytes) {
    _checkSize(bytes);
    return runOffload(() => const CsvImporter().inspect(bytes));
  }

  Future<ParsedBook> parseCsvColumn(
    Uint8List bytes, {
    required String fileName,
    required int column,
    required bool hasHeader,
  }) =>
      runOffload(
        () => const CsvImporter().parseColumn(bytes, fileName: fileName, column: column, hasHeader: hasHeader),
      );

  void _checkSize(Uint8List bytes) {
    if (bytes.isEmpty) throw const ImportException(ImportErrorType.emptyBook);
    if (bytes.length > ImportConstants.maxFileBytes) {
      throw const ImportException(ImportErrorType.tooLarge);
    }
  }
}
