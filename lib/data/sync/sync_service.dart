import 'dart:async';

import '../../domain/models/achievement.dart';
import '../../domain/models/book.dart';
import '../../domain/models/reading_session.dart';
import '../../domain/models/user_profile.dart';
import '../../services/crash_reporter.dart';
import '../local/json_store.dart';
import '../remote/remote_data_source.dart';

/// Offline-first synchronisation.
///
/// Local storage is always the source of truth for the UI. Writes are pushed
/// in the background; Firestore queues them while offline and the
/// `syncPending` flags let us retry anything that never reached the server.
class SyncService {
  SyncService({
    required this.uid,
    required RemoteDataSource remote,
    required JsonStore<Book> books,
    required JsonStore<ReadingSession> sessions,
    required JsonStore<UnlockedAchievement> achievements,
    required JsonStore<UserProfile> profiles,
    required KeyValueStore meta,
    required CrashReporter crash,
  })  : _remote = remote,
        _books = books,
        _sessions = sessions,
        _achievements = achievements,
        _profiles = profiles,
        _meta = meta,
        _crash = crash;

  final String uid;
  final RemoteDataSource _remote;
  final JsonStore<Book> _books;
  final JsonStore<ReadingSession> _sessions;
  final JsonStore<UnlockedAchievement> _achievements;
  final JsonStore<UserProfile> _profiles;
  final KeyValueStore _meta;
  final CrashReporter _crash;

  static const String deletedBooksKey = 'deletedBooks';

  bool _syncing = false;

  bool get isEnabled => _remote.isAvailable;

  void pushBook(Book book) => unawaited(_pushBook(book));

  Future<void> _pushBook(Book book) async {
    if (!isEnabled) return;
    try {
      await _remote.upsertBook(uid, book.toRemoteJson());
      final latest = _books.get(book.id);
      if (latest != null && latest.updatedAt == book.updatedAt) {
        await _books.put(latest.copyWith(syncPending: false, updatedAt: latest.updatedAt));
      }
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'sync: book');
    }
  }

  void pushSession(ReadingSession session) => unawaited(_pushSession(session));

  Future<void> _pushSession(ReadingSession session) async {
    if (!isEnabled) return;
    try {
      await _remote.addSession(uid, session.toRemoteJson());
      await _sessions.put(session.markSynced());
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'sync: session');
    }
  }

  void pushProfile(UserProfile profile) => unawaited(_pushProfile(profile));

  Future<void> _pushProfile(UserProfile profile) async {
    if (!isEnabled) return;
    try {
      await _remote.upsertProfile(uid, profile.toEditableJson());
      final latest = _profiles.get(uid);
      if (latest != null) await _profiles.put(latest.copyWith(syncPending: false));
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'sync: profile');
    }
  }

  void deleteBook(String bookId) => unawaited(_deleteBook(bookId));

  Future<void> _deleteBook(String bookId) async {
    final tombstones = {..._meta.getStringList(deletedBooksKey), bookId};
    await _meta.putStringList(deletedBooksKey, tombstones.toList());
    if (!isEnabled) return;
    try {
      await _remote.deleteBook(uid, bookId);
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'sync: delete book');
    }
  }

  /// Full two-way reconciliation. Safe to call repeatedly; it is a no-op when
  /// a sync is already running or the backend isn't configured.
  Future<void> synchronize() async {
    if (!isEnabled || _syncing) return;
    _syncing = true;
    try {
      await _pushPending();
      await _pull();
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'sync: full');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushPending() async {
    for (final id in _meta.getStringList(deletedBooksKey)) {
      await _remote.deleteBook(uid, id);
    }
    for (final book in _books.all.where((b) => b.syncPending)) {
      await _pushBook(book);
    }
    for (final session in _sessions.all.where((s) => !s.synced)) {
      await _pushSession(session);
    }
    final profile = _profiles.get(uid);
    if (profile != null && profile.syncPending) await _pushProfile(profile);
  }

  Future<void> _pull() async {
    final tombstones = _meta.getStringList(deletedBooksKey).toSet();

    final remoteBooks = await _remote.fetchBooks(uid);
    final merged = <Book>[];
    for (final json in remoteBooks) {
      final remote = Book.fromJson(json);
      if (remote.id.isEmpty || tombstones.contains(remote.id)) continue;
      final local = _books.get(remote.id);
      if (local == null) {
        merged.add(remote.copyWith(
          contentAvailable: false,
          syncPending: false,
          updatedAt: remote.updatedAt,
        ));
      } else if (!local.syncPending && remote.updatedAt.isAfter(local.updatedAt)) {
        merged.add(Book.fromJson({
          ...remote.toRemoteJson(),
          'coverPath': local.coverPath,
          'contentAvailable': local.contentAvailable,
          'syncPending': false,
          'bookmarks': [for (final bookmark in local.bookmarks) bookmark.toJson()],
        }));
      }
    }
    await _books.putAll(merged);

    final remoteSessions = await _remote.fetchSessions(uid);
    await _sessions.putAll([
      for (final json in remoteSessions)
        if (!_sessions.contains(json['sessionId']?.toString() ?? ''))
          ReadingSession.fromJson(json).markSynced(),
    ]);

    final remoteAchievements = await _remote.fetchAchievements(uid);
    await _achievements.putAll([
      for (final json in remoteAchievements) UnlockedAchievement.fromJson(json),
    ]);

    final remoteProfile = await _remote.fetchProfile(uid);
    final local = _profiles.get(uid);
    if (remoteProfile != null && local != null && !local.syncPending) {
      final remote = UserProfile.fromJson({...local.toJson(), ...remoteProfile});
      await _profiles.put(local.copyWith(
        name: remote.name,
        avatar: remote.avatar,
        readingGoalMinutes: remote.readingGoalMinutes,
        currentWpm: remote.currentWpm,
        syncPending: false,
      ));
    }
  }
}
