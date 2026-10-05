import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/utils/sanitize.dart';
import '../../../data/importers/csv_importer.dart';
import '../../../data/importers/importer_registry.dart';
import '../../../data/providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/book_content.dart';
import '../../../services/analytics_service.dart';

sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportProcessing extends ImportState {
  const ImportProcessing(this.fileName);
  final String fileName;
}

class ImportCsvChoice extends ImportState {
  const ImportCsvChoice({
    required this.fileName,
    required this.bytes,
    required this.inspection,
    required this.column,
    required this.hasHeader,
  });

  final String fileName;
  final Uint8List bytes;
  final CsvInspection inspection;
  final int column;
  final bool hasHeader;

  ImportCsvChoice copyWith({int? column, bool? hasHeader}) => ImportCsvChoice(
        fileName: fileName,
        bytes: bytes,
        inspection: inspection,
        column: column ?? this.column,
        hasHeader: hasHeader ?? this.hasHeader,
      );
}

class ImportReview extends ImportState {
  ImportReview({
    required this.fileName,
    required this.format,
    required this.book,
    this.saving = false,
    String? bookId,
  }) : bookId = bookId ?? const Uuid().v4();

  final String fileName;
  final BookFormat format;
  final ParsedBook book;
  final bool saving;

  /// Fixed for the whole review so the preview cover matches the saved book.
  final String bookId;

  ImportReview copyWith({ParsedBook? book, bool? saving}) => ImportReview(
        fileName: fileName,
        format: format,
        book: book ?? this.book,
        saving: saving ?? this.saving,
        bookId: bookId,
      );
}

class ImportDone extends ImportState {
  const ImportDone(this.book);
  final Book book;
}

class ImportFailed extends ImportState {
  const ImportFailed(this.message);
  final String message;
}

final importControllerProvider =
    NotifierProvider.autoDispose<ImportController, ImportState>(ImportController.new);

class ImportController extends Notifier<ImportState> {
  static const int maxCoverBytes = 8 * 1024 * 1024;

  @override
  ImportState build() => const ImportIdle();

  ImporterRegistry get _registry => ref.read(importerRegistryProvider);

  void reset() => state = const ImportIdle();

  Future<void> pickFile() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [...ImportConstants.supportedExtensions, ...ImportConstants.plannedExtensions],
        withData: true,
      );
    } on Object catch (e) {
      state = ImportFailed(AppFailure.from(e).message);
      return;
    }
    final file = result?.files.firstOrNull;
    if (file == null) return;
    if (file.size > ImportConstants.maxFileBytes) {
      state = ImportFailed(const ImportException(ImportErrorType.tooLarge).userMessage);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      state = const ImportFailed("We couldn't read that file. Try saving it to your device first.");
      return;
    }
    await importBytes(bytes, file.name);
  }

  Future<void> importBytes(Uint8List bytes, String fileName) async {
    state = ImportProcessing(fileName);
    try {
      if (_registry.isCsv(fileName)) {
        final inspection = await _registry.inspectCsv(bytes);
        if (!ref.mounted) return;
        if (inspection.columns.length > 1) {
          state = ImportCsvChoice(
            fileName: fileName,
            bytes: bytes,
            inspection: inspection,
            column: inspection.suggestedColumn,
            hasHeader: inspection.hasHeader,
          );
          return;
        }
        await _parseCsv(bytes, fileName, column: 0, hasHeader: inspection.hasHeader);
        return;
      }
      final format = _registry.forFile(fileName).format;
      final parsed = await _registry.parse(bytes, fileName);
      if (!ref.mounted) return;
      state = ImportReview(fileName: fileName, format: format, book: _clean(parsed));
    } on Object catch (e) {
      if (ref.mounted) state = ImportFailed(_message(e));
    }
  }

  void setCsvColumn(int column) {
    final s = state;
    if (s is ImportCsvChoice) state = s.copyWith(column: column);
  }

  void setCsvHeader(bool hasHeader) {
    final s = state;
    if (s is ImportCsvChoice) state = s.copyWith(hasHeader: hasHeader);
  }

  Future<void> confirmCsv() async {
    final s = state;
    if (s is! ImportCsvChoice) return;
    state = ImportProcessing(s.fileName);
    try {
      await _parseCsv(s.bytes, s.fileName, column: s.column, hasHeader: s.hasHeader);
    } on Object catch (e) {
      if (ref.mounted) state = ImportFailed(_message(e));
    }
  }

  Future<void> _parseCsv(Uint8List bytes, String fileName, {required int column, required bool hasHeader}) async {
    final parsed = await _registry.parseCsvColumn(bytes, fileName: fileName, column: column, hasHeader: hasHeader);
    if (!ref.mounted) return;
    state = ImportReview(fileName: fileName, format: BookFormat.csv, book: _clean(parsed));
  }

  // --- review edits ----------------------------------------------------------

  void _edit(ParsedBook Function(ParsedBook) change) {
    final s = state;
    if (s is ImportReview && !s.saving) state = s.copyWith(book: change(s.book));
  }

  void setTitle(String title) => _edit((b) => b.copyWith(title: title));
  void setAuthor(String author) => _edit((b) => b.copyWith(author: author));

  void renameChapter(int index, String title) => _edit((b) {
        final chapters = [...b.chapters];
        chapters[index] = chapters[index].copyWith(
          title: Sanitize.line(title, maxLength: ImportConstants.maxChapterTitleLength),
        );
        return b.copyWith(chapters: chapters);
      });

  void removeChapter(int index) => _edit((b) {
        if (b.chapters.length <= 1) return b;
        return b.copyWith(chapters: [...b.chapters]..removeAt(index));
      });

  /// Joins a chapter into the one before it (useful when a heading was
  /// detected where there wasn't one).
  void mergeWithPrevious(int index) => _edit((b) {
        if (index <= 0) return b;
        final chapters = [...b.chapters];
        final previous = chapters[index - 1];
        chapters[index - 1] = previous.copyWith(paragraphs: [...previous.paragraphs, ...chapters[index].paragraphs]);
        chapters.removeAt(index);
        return b.copyWith(chapters: chapters);
      });

  Future<void> pickCover() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      final file = result?.files.firstOrNull;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      if (bytes.length > maxCoverBytes) {
        throw const AppFailure('That image is too large. Choose one under 8 MB.');
      }
      final ext = ImporterRegistry.extensionOf(file.name);
      _edit((b) => b.copyWith(coverBytes: bytes, coverExtension: ext == 'png' ? 'png' : 'jpg'));
    } on AppFailure {
      rethrow;
    } on Object catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> save() async {
    final s = state;
    if (s is! ImportReview || s.saving) return;
    final title = Sanitize.line(s.book.title, maxLength: ImportConstants.maxTitleLength);
    if (title.isEmpty) throw const AppFailure('Give your book a title before saving.');
    state = s.copyWith(saving: true);
    try {
      final book = await ref.read(bookRepositoryProvider).addParsedBook(
            s.book.copyWith(
              title: title,
              author: Sanitize.line(s.book.author, maxLength: ImportConstants.maxAuthorLength),
            ),
            format: s.format,
            id: s.bookId,
          );
      await ref.read(analyticsProvider).log(AnalyticsEvents.bookImported, {
        'format': s.format.name,
        'chapter_count': book.chapterCount,
      });
      if (ref.mounted) state = ImportDone(book);
    } on Object catch (e) {
      if (ref.mounted) state = s.copyWith(saving: false);
      throw AppFailure.from(e);
    }
  }

  ParsedBook _clean(ParsedBook book) => book.copyWith(
        title: Sanitize.line(book.title, maxLength: ImportConstants.maxTitleLength),
        author: Sanitize.line(book.author, maxLength: ImportConstants.maxAuthorLength),
      );

  String _message(Object e) => AppFailure.from(e).message;
}
