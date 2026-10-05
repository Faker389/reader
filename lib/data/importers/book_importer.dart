import 'dart:typed_data';

import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';

/// Contract for every file format. Implementations are pure and synchronous
/// so they can run inside a background isolate.
abstract interface class BookImporter {
  /// Lower-case file extensions this importer handles.
  Set<String> get extensions;

  BookFormat get format;

  /// Whether the importer is implemented. Planned formats (e.g. PDF) are
  /// registered so the UI can show them as "coming soon".
  bool get isAvailable;

  ParsedBook parse(Uint8List bytes, {required String fileName});
}

String titleFromFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final cleaned = base.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return 'Untitled';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
