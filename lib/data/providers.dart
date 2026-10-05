import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../domain/models/achievement.dart';
import '../domain/models/book.dart';
import '../domain/models/reading_session.dart';
import '../domain/models/user_profile.dart';
import 'importers/importer_registry.dart';
import 'local/json_store.dart';
import 'remote/firestore_remote_data_source.dart';
import 'remote/remote_data_source.dart';
import 'repositories/achievement_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/book_repository.dart';
import 'repositories/firebase_auth_repository.dart';
import 'repositories/local_auth_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';
import 'sync/sync_service.dart';
import 'user_scope.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(KeyValueStore(ref.watch(localDatabaseProvider).appBox)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final env = ref.watch(appEnvironmentProvider);
  return env.firebaseAvailable ? FirebaseAuthRepository() : LocalAuthRepository(env.database.appBox);
});

final remoteDataSourceProvider = Provider<RemoteDataSource>(
  (ref) => ref.watch(firebaseAvailableProvider) ? FirestoreRemoteDataSource() : const NoopRemoteDataSource(),
);

final importerRegistryProvider = Provider<ImporterRegistry>((ref) => const ImporterRegistry());

/// Auth state. The user's local storage is opened *before* the user is
/// emitted, so everything downstream can read it synchronously.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final db = ref.watch(localDatabaseProvider);
  final crash = ref.watch(crashReporterProvider);
  return auth.authStateChanges().asyncMap((user) async {
    if (user != null) await db.openUserScope(user.uid);
    await crash.setUser(user?.uid);
    return user;
  });
});

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authStateProvider).value);

final currentUidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider.select((u) => u?.uid)));

class SignedOutException implements Exception {
  const SignedOutException();
}

/// Only read from authenticated screens; the router guarantees a user exists.
final userScopeProvider = Provider<UserScope>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw const SignedOutException();
  final boxes = ref.watch(localDatabaseProvider).userBoxes;
  if (boxes == null || boxes.uid != uid) throw const SignedOutException();
  final scope = UserScope.create(
    boxes: boxes,
    files: ref.watch(fileStoreProvider).forUser(uid),
    remote: ref.watch(remoteDataSourceProvider),
    crash: ref.watch(crashReporterProvider),
  );
  ref.onDispose(scope.dispose);
  return scope;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) => ref.watch(userScopeProvider).books);
final sessionRepositoryProvider = Provider<SessionRepository>((ref) => ref.watch(userScopeProvider).sessions);
final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ref.watch(userScopeProvider).profile);
final achievementRepositoryProvider =
    Provider<AchievementRepository>((ref) => ref.watch(userScopeProvider).achievements);
final syncServiceProvider = Provider<SyncService>((ref) => ref.watch(userScopeProvider).sync);

final booksProvider = StreamProvider<List<Book>>((ref) => ref.watch(bookRepositoryProvider).watchAll());

final sessionsProvider =
    StreamProvider<List<ReadingSession>>((ref) => ref.watch(sessionRepositoryProvider).watchAll());

final profileProvider = StreamProvider<UserProfile?>((ref) => ref.watch(profileRepositoryProvider).watch());

final unlockedAchievementsProvider =
    StreamProvider<Map<String, UnlockedAchievement>>((ref) => ref.watch(achievementRepositoryProvider).watch());

final bookProvider = Provider.family<Book?, String>((ref, id) {
  final books = ref.watch(booksProvider).value;
  if (books == null) return ref.watch(bookRepositoryProvider).byId(id);
  for (final book in books) {
    if (book.id == id) return book;
  }
  return null;
});
