import '../../domain/models/user_profile.dart';

abstract interface class AuthRepository {
  /// True when running without Firebase: accounts live on this device only.
  bool get isLocalMode;
  bool get supportsGoogle;

  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmail({required String email, required String password});
  Future<AppUser> signUpWithEmail({required String name, required String email, required String password});

  /// Returns null if the user cancelled.
  Future<AppUser?> signInWithGoogle();

  Future<void> sendPasswordReset(String email);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();

  /// Confirms identity before sensitive operations. [password] is required
  /// for email accounts; Google accounts re-run the Google flow.
  Future<void> reauthenticate({String? password});

  /// Deletes the authentication record. Callers delete user data first.
  Future<void> deleteAccount();
}
