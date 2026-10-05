import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/sanitize.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';
import '../../domain/reading/tokenizer.dart';
import '../importers/txt_importer.dart';
import '../local/file_store.dart';
import '../local/json_store.dart';
import '../samples/sample_books.dart';
import '../sync/sync_service.dart';

class BookRepository {
  BookRepository({
    required JsonStore<Book> store,
    required UserFiles files,
    required SyncService sync,
    required KeyValueStore meta,
    AssetBundle? assets,
  })  : _store = store,
        _files = files,
        _sync = sync,
        _meta = meta,
        _assets = assets ?? rootBundle;

  final JsonStore<Book> _store;
  final UserFiles _files;
  final SyncService _sync;
  final KeyValueStore _meta;
  final AssetBundle _assets;

  static const String _seededKey = 'samplesSeededVersion';

  String? _cachedContentId;
  BookContent? _cachedContent;

  List<Book> get all => _store.all;
  Stream<List<Book>> watchAll() => _store.watch();
  Book? byId(String id) => _store.get(id);

  File? coverFile(Book book) => book.coverPath == null ? null : _files.resolve(book.coverPath!);

  /// Loads and tokenises the book text in a background isolate. The most
  /// recently opened book is cached so returning to the reader is instant.
  Future<BookContent> loadContent(String bookId) async {
    if (_cachedContentId == bookId && _cachedContent != null) return _cachedContent!;
    final file = _files.resolve(UserFiles.contentPath(bookId));
    if (!await file.exists()) {
      throw const AppFailure(
        "This book's text isn't on this device. Import the file again to keep reading.",
        kind: FailureKind.storage,
      );
    }
    final path = file.path;
    final content = await Isolate.run(() {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return Tokenizer.tokenize(ParsedBook.chaptersFromContentJson(json));
    });
    if (content.isEmpty) throw const ImportException(ImportErrorType.emptyBook);
    _cachedContentId = bookId;
    _cachedContent = content;
    return content;
  }

  /// Persists a parsed book: text to a private file, metadata to the store.
  Future<Book> addParsedBook(
    ParsedBook parsed, {
    required BookFormat format,
    BookSource source = BookSource.imported,
    String? id,
    String? description,
    Uint8List? coverBytes,
    String? coverExtension,
  }) async {
    final bookId = id ?? const Uuid().v4();
    final chapters = parsed.chapters;
    final prepared = await Isolate.run(() {
      final content = Tokenizer.tokenize(chapters);
      return (
        json: jsonEncode(ParsedBook(title: '', author: '', chapters: chapters).toContentJson()),
        words: content.length,
        chapters: content.chapters.length,
      );
    });
    if (prepared.words == 0) throw const ImportException(ImportErrorType.emptyBook);

    await _files.writeString(UserFiles.contentPath(bookId), prepared.json);

    String? coverPath;
    final cover = coverBytes ?? parsed.coverBytes;
    if (cover != null) {
      coverPath = UserFiles.coverPath(bookId, coverExtension ?? parsed.coverExtension ?? 'jpg');
      await _files.writeBytes(coverPath, cover);
    }

    final now = DateTime.now();
    final existing = _store.get(bookId);
    final book = existing != null
        ? existing.copyWith(
            totalWords: prepared.words,
            chapterCount: prepared.chapters,
            contentAvailable: true,
            coverPath: coverPath,
          )
        : Book(
            id: bookId,
            title: Sanitize.line(parsed.title, maxLength: ImportConstants.maxTitleLength),
            author: Sanitize.line(parsed.author, maxLength: ImportConstants.maxAuthorLength),
            format: format,
            source: source,
            totalWords: prepared.words,
            chapterCount: prepared.chapters,
            createdAt: now,
            updatedAt: now,
            coverPath: coverPath,
            description: description,
          );
    await _store.put(book);
    _sync.pushBook(book);
    return book;
  }

  /// Adds the bundled public-domain classics on first launch. Samples the user
  /// deleted are not re-added.
  Future<void> seedSamples() async {
    final seeded = int.tryParse(_meta.getString(_seededKey) ?? '') ?? 0;
    final deleted = _meta.getStringList(SyncService.deletedBooksKey).toSet();
    final needsRefresh = seeded < SampleBooks.version;
    for (final sample in SampleBooks.all) {
      if (deleted.contains(sample.id)) continue;
      final existing = _store.get(sample.id);
      final hasContent = await _files.exists(UserFiles.contentPath(sample.id));
      if (existing != null && hasContent && !needsRefresh) continue;
      final text = await _assets.loadString(sample.asset);
      final chapters = await Isolate.run(() => TxtImporter.parseText(text));
      await addParsedBook(
        ParsedBook(title: sample.title, author: sample.author, chapters: chapters),
        format: BookFormat.sample,
        source: BookSource.sample,
        id: sample.id,
        description: sample.description,
      );
    }
    await _meta.putString(_seededKey, '${SampleBooks.version}');
  }

  /// Frequent, local-only progress save used while reading.
  Future<void> saveProgress(String id, {required int wordIndex, required int chapter}) async {
    final book = _store.get(id);
    if (book == null) return;
    await _store.put(book.copyWith(
      currentWordIndex: wordIndex,
      currentChapter: chapter,
      lastOpenedAt: DateTime.now(),
    ));
  }

  Future<Book?> markOpened(String id) async {
    final book = _store.get(id);
    if (book == null) return null;
    final updated = book.copyWith(lastOpenedAt: DateTime.now());
    await _store.put(updated);
    return updated;
  }

  Future<Book?> recordSession(
    String id, {
    required int wordsRead,
    required int seconds,
    required int endIndex,
    required int chapter,
    required bool finished,
  }) async {
    final book = _store.get(id);
    if (book == null) return null;
    final now = DateTime.now();
    final updated = book.copyWith(
      currentWordIndex: endIndex,
      currentChapter: chapter,
      wordsRead: book.wordsRead + wordsRead,
      totalReadingSeconds: book.totalReadingSeconds + seconds,
      sessionsCount: book.sessionsCount + 1,
      lastOpenedAt: now,
      completed: finished || book.completed,
      completedAt: finished && !book.completed ? now : book.completedAt,
    );
    await _store.put(updated);
    _sync.pushBook(updated);
    return updated;
  }

  Future<void> pushProgress(String id) async {
    final book = _store.get(id);
    if (book != null) _sync.pushBook(book);
  }

  Future<void> toggleFavorite(String id) => _update(id, (b) => b.copyWith(favorite: !b.favorite));

  Future<void> setCompleted(String id, bool completed) => _update(
        id,
        (b) => completed
            ? b.copyWith(completed: true, completedAt: DateTime.now())
            : b.copyWith(completed: false, clearCompletedAt: true),
      );

  Future<void> restart(String id) =>
      _update(id, (b) => b.copyWith(currentWordIndex: 0, currentChapter: 0, completed: false, clearCompletedAt: true));

  Future<void> updateDetails(String id, {String? title, String? author}) => _update(
        id,
        (b) => b.copyWith(
          title: title == null ? null : Sanitize.line(title, maxLength: ImportConstants.maxTitleLength),
          author: author == null ? null : Sanitize.line(author, maxLength: ImportConstants.maxAuthorLength),
        ),
      );

  Future<void> delete(String id) async {
    final book = _store.get(id);
    await _store.delete(id);
    await _files.delete(UserFiles.contentPath(id));
    await _files.delete(book?.coverPath);
    if (_cachedContentId == id) {
      _cachedContentId = null;
      _cachedContent = null;
    }
    _sync.deleteBook(id);
  }

  Future<void> _update(String id, Book Function(Book) change) async {
    final book = _store.get(id);
    if (book == null) return;
    final updated = change(book);
    await _store.put(updated);
    _sync.pushBook(updated);
  }
}
