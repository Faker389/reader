import 'dart:typed_data';

import '../../core/errors/app_failure.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';
import 'book_importer.dart';

/// Placeholder that reserves the PDF slot in the importer registry.
///
/// To add PDF support: extract text per page with a PDF text library, group
/// pages into chapters using the outline when present, return a [ParsedBook]
/// and flip [isAvailable] to true. Nothing else in the app needs to change.
class PdfImporter implements BookImporter {
  const PdfImporter();

  @override
  Set<String> get extensions => const {'pdf'};

  @override
  BookFormat get format => BookFormat.txt;

  @override
  bool get isAvailable => false;

  @override
  ParsedBook parse(Uint8List bytes, {required String fileName}) =>
      throw const ImportException(ImportErrorType.plannedFormat);
}
