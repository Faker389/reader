import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../../../data/local/file_store.dart';
import '../../../data/local/local_database.dart';
import '../../../data/providers.dart';
import '../../../data/remote/remote_data_source.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../services/crash_reporter.dart';
import '../../../services/notification_service.dart';

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    auth: ref.watch(authRepositoryProvider),
    remote: ref.watch(remoteDataSourceProvider),
    database: ref.watch(localDatabaseProvider),
    files: ref.watch(fileStoreProvider),
    notifications: ref.watch(notificationServiceProvider),
    crash: ref.watch(crashReporterProvider),
  ),
);

/// Sign-out and account deletion. Dependencies are captured up front because
/// signing out tears down the user-scoped providers mid-operation.
class AccountService {
  AccountService({
    required AuthRepository auth,
    required RemoteDataSource remote,
    required LocalDatabase database,
    required FileStore files,
    required NotificationService notifications,
    required CrashReporter crash,
  })  : _auth = auth,
        _remote = remote,
        _database = database,
        _files = files,
        _notifications = notifications,
        _crash = crash;

  final AuthRepository _auth;
  final RemoteDataSource _remote;
  final LocalDatabase _database;
  final FileStore _files;
  final NotificationService _notifications;
  final CrashReporter _crash;

  Future<void> signOut() async {
    try {
      await _notifications.cancelAll();
      await _auth.signOut();
    } on Object catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Permanently removes the account: cloud data, then the auth record, then
  /// everything stored on this device for the user.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    try {
      await _auth.reauthenticate(password: password);
      await _remote.deleteAllUserData(user.uid);
      await _auth.deleteAccount();
    } on Object catch (e) {
      throw AppFailure.from(e);
    }
    try {
      await _notifications.cancelAll();
      await _database.deleteUserScope(user.uid);
      await _files.forUser(user.uid).deleteAll();
    } on Object catch (e, s) {
      // The account is already gone; leftover local files are harmless and
      // unreachable, so report rather than surface an error.
      _crash.recordNonFatal(e, s, reason: 'local cleanup after account deletion');
    }
  }
}
