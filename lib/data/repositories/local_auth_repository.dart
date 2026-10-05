import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/models/user_profile.dart';
import 'auth_repository.dart';

/// Device-only accounts used when Firebase isn't configured, so the complete
/// app can be explored before any backend setup. Passwords are salted and
/// hashed; nothing leaves the device.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._box) {
    final uid = _box.get(_sessionKey);
    _current = uid == null ? null : _userFor(uid);
    _controller = StreamController<AppUser?>.broadcast();
  }

  static const String _accountsKey = 'local_accounts';
  static const String _sessionKey = 'local_session';
  static const int _hashRounds = 10000;

  final Box<String> _box;
  late final StreamController<AppUser?> _controller;
  AppUser? _current;

  @override
  bool get isLocalMode => true;

  @override
  bool get supportsGoogle => false;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  Map<String, dynamic> _accounts() {
    final raw = _box.get(_accountsKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveAccounts(Map<String, dynamic> accounts) => _box.put(_accountsKey, jsonEncode(accounts));

  Map<String, dynamic>? _accountByUid(String uid) {
    for (final value in _accounts().values) {
      final account = Map<String, dynamic>.from(value as Map);
      if (account['uid'] == uid) return account;
    }
    return null;
  }

  AppUser? _userFor(String uid) {
    final account = _accountByUid(uid);
    if (account == null) return null;
    return AppUser(
      uid: uid,
      email: account['email'] as String,
      displayName: account['name'] as String?,
      provider: AuthProviderKind.local,
      lastSignInAt: DateTime.now(),
    );
  }

  String _hash(String password, String salt) {
    List<int> digest = utf8.encode('$salt:$password');
    for (var i = 0; i < _hashRounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Encode(digest);
  }

  Future<AppUser> _setSession(String uid) async {
    await _box.put(_sessionKey, uid);
    _current = _userFor(uid);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final raw = _accounts()[key];
    if (raw == null) throw const AppFailure("Email or password doesn't match. Please try again.");
    final account = Map<String, dynamic>.from(raw as Map);
    if (_hash(password, account['salt'] as String) != account['hash']) {
      throw const AppFailure("Email or password doesn't match. Please try again.");
    }
    return _setSession(account['uid'] as String);
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final accounts = _accounts();
    if (accounts.containsKey(key)) {
      throw const AppFailure('An account with this email already exists. Try signing in instead.');
    }
    final random = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    final uid = 'local-${const Uuid().v4()}';
    accounts[key] = {
      'uid': uid,
      'email': email.trim(),
      'name': name.trim(),
      'salt': salt,
      'hash': _hash(password, salt),
    };
    await _saveAccounts(accounts);
    return _setSession(uid);
  }

  @override
  Future<AppUser?> signInWithGoogle() async => throw const AppFailure(
        'Google Sign-In becomes available once Firebase is configured. Use email for now.',
      );

  @override
  Future<void> sendPasswordReset(String email) async => throw const AppFailure(
        'Password reset emails need Firebase. In offline demo mode, create a new account instead.',
      );

  @override
  Future<void> updateDisplayName(String name) async {
    final current = _current;
    if (current == null) return;
    final accounts = _accounts();
    for (final entry in accounts.entries) {
      final account = Map<String, dynamic>.from(entry.value as Map);
      if (account['uid'] == current.uid) {
        accounts[entry.key] = {...account, 'name': name.trim()};
      }
    }
    await _saveAccounts(accounts);
    _current = _userFor(current.uid);
  }

  @override
  Future<void> signOut() async {
    await _box.delete(_sessionKey);
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    final current = _current;
    if (current == null) throw const AppFailure('Please sign in again.');
    final account = _accountByUid(current.uid);
    if (account == null || password == null || _hash(password, account['salt'] as String) != account['hash']) {
      throw const AppFailure("That password doesn't match.");
    }
  }

  @override
  Future<void> deleteAccount() async {
    final current = _current;
    if (current == null) return;
    final accounts = _accounts()..removeWhere((_, v) => (v as Map)['uid'] == current.uid);
    await _saveAccounts(accounts);
    await signOut();
  }
}
