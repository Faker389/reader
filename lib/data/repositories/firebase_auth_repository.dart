import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/models/user_profile.dart';
import 'auth_repository.dart';

/// TODO(firebase): For Google Sign-In on Android, set this to the *Web* OAuth
/// client id from the Firebase console (or rely on `default_web_client_id`
/// from google-services.json). On iOS, add the REVERSED_CLIENT_ID URL scheme
/// from GoogleService-Info.plist to ios/Runner/Info.plist.
abstract final class GoogleSignInConfig {
  static const String? serverClientId = null;
  static const String? iosClientId = null;
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  Future<void>? _googleInit;

  @override
  bool get isLocalMode => false;

  @override
  bool get supportsGoogle => true;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _map(result.user)!;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await result.user?.updateDisplayName(name.trim());
    await result.user?.reload();
    return _map(_auth.currentUser ?? result.user)!;
  }

  Future<void> _ensureGoogle() => _googleInit ??= GoogleSignIn.instance.initialize(
        serverClientId: GoogleSignInConfig.serverClientId,
        clientId: GoogleSignInConfig.iosClientId,
      );

  Future<String> _googleIdToken() async {
    await _ensureGoogle();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppFailure("Google didn't return a sign-in token. Please try again.");
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const _Cancelled();
      throw AppFailure("We couldn't connect to Google. Please try again.", cause: e, kind: FailureKind.auth);
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final idToken = await _googleIdToken();
      final result = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      return _map(result.user);
    } on _Cancelled {
      return null;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> updateDisplayName(String name) async => _auth.currentUser?.updateDisplayName(name.trim());

  @override
  Future<void> signOut() async {
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object {
        // Not signed in with Google; nothing to do.
      }
    }
    await _auth.signOut();
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    final isGoogle = user.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);
    try {
      if (isGoogle) {
        final idToken = await _googleIdToken();
        await user.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      } else {
        if (password == null || password.isEmpty) {
          throw const AppFailure('Enter your password to continue.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email ?? '', password: password),
        );
      }
    } on _Cancelled {
      throw const AppFailure('Confirmation was cancelled.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.disconnect();
      } on Object {
        // Best effort.
      }
    }
  }

  AppUser? _map(User? user) {
    if (user == null) return null;
    final isGoogle = user.providerData.any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: isGoogle ? AuthProviderKind.google : AuthProviderKind.password,
      lastSignInAt: user.metadata.lastSignInTime,
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
