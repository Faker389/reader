import '../domain/models/achievement.dart';
import '../domain/models/book.dart';
import '../domain/models/reading_session.dart';
import '../domain/models/user_profile.dart';
import '../services/crash_reporter.dart';
import 'local/file_store.dart';
import 'local/json_store.dart';
import 'local/local_database.dart';
import 'remote/remote_data_source.dart';
import 'repositories/achievement_repository.dart';
import 'repositories/book_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/session_repository.dart';
import 'sync/sync_service.dart';

/// Everything that belongs to the signed-in user, created together so that
/// stores, sync and repositories always share the same underlying boxes.
class UserScope {
  UserScope._({
    required this.uid,
    required this.sync,
    required this.books,
    required this.sessions,
    required this.profile,
    required this.achievements,
    required List<JsonStore<Object?>> stores,
  }) : _stores = stores;

  factory UserScope.create({
    required UserBoxes boxes,
    required UserFiles files,
    required RemoteDataSource remote,
    required CrashReporter crash,
  }) {
    final uid = boxes.uid;
    final bookStore = JsonStore<Book>(
      box: boxes.books,
      decode: Book.fromJson,
      encode: (b) => b.toJson(),
      idOf: (b) => b.id,
    );
    final sessionStore = JsonStore<ReadingSession>(
      box: boxes.sessions,
      decode: ReadingSession.fromJson,
      encode: (s) => s.toJson(),
      idOf: (s) => s.id,
    );
    final achievementStore = JsonStore<UnlockedAchievement>(
      box: boxes.achievements,
      decode: UnlockedAchievement.fromJson,
      encode: (a) => a.toJson(),
      idOf: (a) => a.id,
    );
    final profileStore = JsonStore<UserProfile>(
      box: boxes.profile,
      decode: UserProfile.fromJson,
      encode: (p) => p.toJson(),
      idOf: (p) => p.uid,
    );
    final meta = KeyValueStore(boxes.meta);
    final sync = SyncService(
      uid: uid,
      remote: remote,
      books: bookStore,
      sessions: sessionStore,
      achievements: achievementStore,
      profiles: profileStore,
      meta: meta,
      crash: crash,
    );
    return UserScope._(
      uid: uid,
      sync: sync,
      books: BookRepository(store: bookStore, files: files, sync: sync, meta: meta),
      sessions: SessionRepository(store: sessionStore, meta: meta, sync: sync),
      profile: ProfileRepository(uid: uid, store: profileStore, sync: sync, remote: remote, files: files),
      achievements: AchievementRepository(store: achievementStore),
      stores: [bookStore, sessionStore, achievementStore, profileStore],
    );
  }

  final String uid;
  final SyncService sync;
  final BookRepository books;
  final SessionRepository sessions;
  final ProfileRepository profile;
  final AchievementRepository achievements;
  final List<JsonStore<Object?>> _stores;

  void dispose() {
    for (final store in _stores) {
      store.dispose();
    }
  }
}
