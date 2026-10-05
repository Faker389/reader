import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/auth_repository.dart';
import 'user_session.dart';

/// Runs auth actions and exposes a busy flag. Errors are rethrown as
/// [AppFailure]s so screens can show friendly messages.
final authControllerProvider = NotifierProvider.autoDispose<AuthController, bool>(AuthController.new);

class AuthController extends Notifier<bool> {
  @override
  bool build() => false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<T> _run<T>(Future<T> Function() action) async {
    state = true;
    try {
      return await action();
    } on Object catch (e) {
      throw AppFailure.from(e);
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmail(email: email.trim(), password: password));

  Future<void> signUp(String name, String email, String password) => _run(() async {
        // Firebase can emit the new user before the display name is stored,
        // so the session bootstrap applies the typed name to the profile.
        final pending = ref.read(pendingSignUpNameProvider.notifier)..set(name.trim());
        try {
          await _auth.signUpWithEmail(name: name.trim(), email: email.trim(), password: password);
        } on Object {
          pending.set(null);
          rethrow;
        }
      });

  /// Returns false when the user dismissed the Google sheet.
  Future<bool> signInWithGoogle() => _run(() async => await _auth.signInWithGoogle() != null);

  Future<void> sendPasswordReset(String email) => _run(() => _auth.sendPasswordReset(email.trim()));
}
