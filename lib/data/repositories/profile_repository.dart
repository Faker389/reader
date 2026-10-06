import 'dart:typed_data';

import '../../core/errors/app_failure.dart';
import '../../core/utils/sanitize.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/stats/reading_stats.dart';
import '../local/file_store.dart';
import '../local/json_store.dart';
import '../remote/remote_data_source.dart';
import '../sync/sync_service.dart';

class ProfileRepository {
  ProfileRepository({
    required this.uid,
    required JsonStore<UserProfile> store,
    required SyncService sync,
    required RemoteDataSource remote,
    required UserFiles files,
  })  : _store = store,
        _sync = sync,
        _remote = remote,
        _files = files;

  final String uid;
  final JsonStore<UserProfile> _store;
  final SyncService _sync;
  final RemoteDataSource _remote;
  final UserFiles _files;

  UserProfile? get current => _store.get(uid);

  Stream<UserProfile?> watch() => _store.watch().map((_) => _store.get(uid));

  /// Creates the profile on first sign-in, seeded with onboarding choices.
  Future<UserProfile> ensure(AppUser user, OnboardingChoices choices) async {
    final existing = current;
    if (existing != null) return existing;

    final remote = _remote.isAvailable ? await _tryFetchRemote() : null;
    final fallbackName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email.split('@').first;
    final profile = remote != null
        ? UserProfile.fromJson({...remote, 'uid': uid, 'syncPending': false})
        : UserProfile(
            uid: uid,
            name: Sanitize.line(fallbackName, maxLength: 60),
            email: user.email,
            avatar: user.photoUrl,
            createdAt: DateTime.now(),
            readingGoalMinutes: choices.goalMinutes,
            currentWpm: choices.startingWpm,
          );
    await _store.put(profile);
    if (remote == null) _sync.pushProfile(profile);
    return profile;
  }

  Future<Map<String, dynamic>?> _tryFetchRemote() async {
    try {
      return await _remote.fetchProfile(uid);
    } on Object {
      return null;
    }
  }

  Future<void> update(UserProfile Function(UserProfile) change) async {
    final profile = current;
    if (profile == null) return;
    final updated = change(profile).copyWith(syncPending: true);
    await _store.put(updated);
    _sync.pushProfile(updated);
  }

  Future<void> setName(String name) =>
      update((p) => p.copyWith(name: Sanitize.line(name, maxLength: 60)));

  Future<void> setGoal(int minutes) => update((p) => p.copyWith(readingGoalMinutes: minutes));

  Future<void> setCurrentWpm(int wpm) async {
    if (current?.currentWpm == wpm) return;
    await update((p) => p.copyWith(currentWpm: wpm));
  }

  /// Stores an avatar privately: in Firebase Storage when available,
  /// otherwise on the device.
  Future<void> setAvatar(Uint8List bytes, String extension) async {
    String avatar;
    if (_remote.isAvailable) {
      try {
        avatar = await _remote.uploadAvatar(uid, bytes, 'image/${extension == 'png' ? 'png' : 'jpeg'}');
      } on Object catch (e) {
        throw AppFailure.from(e);
      }
    } else {
      final relative = '${UserFiles.avatarPath}-${DateTime.now().millisecondsSinceEpoch}.$extension';
      avatar = await _files.writeBytes(relative, bytes);
    }
    await update((p) => p.copyWith(avatar: avatar));
  }

  /// Mirrors locally computed aggregates for display. These fields are not
  /// pushed: the server derives its own values from session logs.
  Future<void> applyStats(ReadingStats stats) async {
    final profile = current;
    if (profile == null) return;
    final lastDay = stats.streak.lastMetDay;
    await _store.put(profile.copyWith(
      totalWordsRead: stats.totalWords,
      totalReadingTime: stats.totalSeconds,
      booksCompleted: stats.booksCompleted,
      currentStreak: stats.streak.current,
      longestStreak: stats.streak.longest,
      lastReadingDate: lastDay == null ? null : DateTime.tryParse(lastDay),
      syncPending: profile.syncPending,
    ));
  }
}
