import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed storage. Values are JSON strings so no type adapters or code
/// generation are required, and models own their own serialisation.
///
/// Data is partitioned per user so that several accounts on one device never
/// see each other's books or sessions.
class LocalDatabase {
  LocalDatabase._(this.appBox);

  static const String _appBoxName = 'fovea_app';
  static const List<String> _userBoxSuffixes = ['books', 'sessions', 'achievements', 'profile', 'meta'];

  static Future<LocalDatabase> open() async {
    await Hive.initFlutter('fovea');
    final app = await Hive.openBox<String>(_appBoxName);
    return LocalDatabase._(app);
  }

  /// Device-wide values: settings, onboarding, local accounts.
  final Box<String> appBox;

  UserBoxes? _user;

  UserBoxes? get userBoxes => _user;

  Future<UserBoxes> openUserScope(String uid) async {
    final existing = _user;
    if (existing != null && existing.uid == uid) return existing;
    await closeUserScope();
    final prefix = scopeKey(uid);
    final boxes = await Future.wait([
      for (final suffix in _userBoxSuffixes) Hive.openBox<String>('${prefix}_$suffix'),
    ]);
    return _user = UserBoxes(
      uid: uid,
      books: boxes[0],
      sessions: boxes[1],
      achievements: boxes[2],
      profile: boxes[3],
      meta: boxes[4],
    );
  }

  Future<void> closeUserScope() async {
    final boxes = _user;
    _user = null;
    if (boxes == null) return;
    await Future.wait([for (final box in boxes.all) box.close()]);
  }

  Future<void> deleteUserScope(String uid) async {
    if (_user?.uid == uid) await closeUserScope();
    final prefix = scopeKey(uid);
    for (final suffix in _userBoxSuffixes) {
      await Hive.deleteBoxFromDisk('${prefix}_$suffix');
    }
  }

  /// Hive box names are case-insensitive, so uids are hashed into a stable,
  /// lowercase key.
  static String scopeKey(String uid) =>
      'u${sha1.convert(utf8.encode(uid)).toString().substring(0, 16)}';
}

class UserBoxes {
  const UserBoxes({
    required this.uid,
    required this.books,
    required this.sessions,
    required this.achievements,
    required this.profile,
    required this.meta,
  });

  final String uid;
  final Box<String> books;
  final Box<String> sessions;
  final Box<String> achievements;
  final Box<String> profile;
  final Box<String> meta;

  List<Box<String>> get all => [books, sessions, achievements, profile, meta];
}
