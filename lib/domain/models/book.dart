import '../../core/utils/json.dart';

enum BookFormat { txt, epub, csv, sample }

enum BookSource { sample, imported }

/// Book metadata plus the reader's progress. The text itself lives in a
/// separate local content file and is never uploaded.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.source,
    required this.totalWords,
    required this.chapterCount,
    required this.createdAt,
    required this.updatedAt,
    this.coverPath,
    this.description,
    this.lastOpenedAt,
    this.currentWordIndex = 0,
    this.currentChapter = 0,
    this.wordsRead = 0,
    this.totalReadingSeconds = 0,
    this.sessionsCount = 0,
    this.completed = false,
    this.completedAt,
    this.favorite = false,
    this.contentAvailable = true,
    this.syncPending = true,
  });

  final String id;
  final String title;
  final String author;
  final BookFormat format;
  final BookSource source;
  final int totalWords;
  final int chapterCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Relative path of a locally stored cover image, if any.
  final String? coverPath;
  final String? description;
  final DateTime? lastOpenedAt;
  final int currentWordIndex;
  final int currentChapter;
  final int wordsRead;
  final int totalReadingSeconds;
  final int sessionsCount;
  final bool completed;
  final DateTime? completedAt;
  final bool favorite;

  /// False when metadata was synced from another device but the text has not
  /// been imported on this one.
  final bool contentAvailable;
  final bool syncPending;

  bool get isSample => source == BookSource.sample;
  bool get isStarted => currentWordIndex > 0 || sessionsCount > 0;
  bool get isInProgress => isStarted && !completed;

  double get progress {
    if (completed) return 1;
    if (totalWords <= 1) return 0;
    return (currentWordIndex / (totalWords - 1)).clamp(0.0, 1.0);
  }

  int get wordsRemaining =>
      completed ? 0 : (totalWords - currentWordIndex).clamp(0, totalWords);

  Duration estimatedTimeAt(int wpm, {int? words}) {
    if (wpm <= 0) return Duration.zero;
    final remaining = words ?? wordsRemaining;
    return Duration(seconds: (remaining / wpm * 60).round());
  }

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    bool clearCover = false,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    int? currentWordIndex,
    int? currentChapter,
    int? wordsRead,
    int? totalReadingSeconds,
    int? sessionsCount,
    bool? completed,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? favorite,
    bool? contentAvailable,
    bool? syncPending,
    int? totalWords,
    int? chapterCount,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      source: source,
      totalWords: totalWords ?? this.totalWords,
      chapterCount: chapterCount ?? this.chapterCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      coverPath: clearCover ? null : (coverPath ?? this.coverPath),
      description: description,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      currentChapter: currentChapter ?? this.currentChapter,
      wordsRead: wordsRead ?? this.wordsRead,
      totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      favorite: favorite ?? this.favorite,
      contentAvailable: contentAvailable ?? this.contentAvailable,
      syncPending: syncPending ?? true,
    );
  }

  /// Local representation, including device-only fields.
  JsonMap toJson() => {
        ...toRemoteJson(),
        'coverPath': coverPath,
        'contentAvailable': contentAvailable,
        'syncPending': syncPending,
      };

  /// Metadata that is safe to synchronise. Contains no book text.
  JsonMap toRemoteJson() => {
        'id': id,
        'title': title,
        'author': author,
        'format': format.name,
        'source': source.name,
        'totalWords': totalWords,
        'chapterCount': chapterCount,
        'description': description,
        'createdAt': millis(createdAt),
        'updatedAt': millis(updatedAt),
        'lastOpened': millis(lastOpenedAt),
        'currentWordIndex': currentWordIndex,
        'currentChapter': currentChapter,
        'wordsRead': wordsRead,
        'totalReadingTime': totalReadingSeconds,
        'sessions': sessionsCount,
        'completed': completed,
        'completedAt': millis(completedAt),
        'favorite': favorite,
        'percentage': progress,
      };

  factory Book.fromJson(JsonMap json) {
    final now = DateTime.now();
    return Book(
      id: json.str('id'),
      title: json.str('title', 'Untitled'),
      author: json.str('author'),
      format: json.enumValue('format', BookFormat.values, BookFormat.txt),
      source: json.enumValue('source', BookSource.values, BookSource.imported),
      totalWords: json.integer('totalWords'),
      chapterCount: json.integer('chapterCount', 1),
      description: json.strOrNull('description'),
      createdAt: json.date('createdAt') ?? now,
      updatedAt: json.date('updatedAt') ?? now,
      lastOpenedAt: json.date('lastOpened'),
      coverPath: json.strOrNull('coverPath'),
      currentWordIndex: json.integer('currentWordIndex'),
      currentChapter: json.integer('currentChapter'),
      wordsRead: json.integer('wordsRead'),
      totalReadingSeconds: json.integer('totalReadingTime'),
      sessionsCount: json.integer('sessions'),
      completed: json.boolean('completed'),
      completedAt: json.date('completedAt'),
      favorite: json.boolean('favorite'),
      contentAvailable: json.boolean('contentAvailable', true),
      syncPending: json.boolean('syncPending', true),
    );
  }
}
