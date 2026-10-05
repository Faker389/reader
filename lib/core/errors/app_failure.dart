import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
/// A failure that is safe to show to users. Raw exceptions never reach the UI;
/// they are converted into an [AppFailure] with a human-readable message.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause, this.kind = FailureKind.unknown});

  final String message;
  final Object? cause;
  final FailureKind kind;

  @override
  String toString() => 'AppFailure($kind): $message';

  static const String genericMessage =
      'Something went wrong. Please try again in a moment.';

  /// Maps any thrown object into a user-facing failure.
  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is ImportException) {
      return AppFailure(error.userMessage, cause: error, kind: FailureKind.import);
    }
    if (error is FirebaseAuthException) return _fromAuth(error);
    if (error is FirebaseException) return _fromFirebase(error);
    if (error is SocketException || error is TimeoutException) {
      return AppFailure(
        "You're offline right now. Your reading still works — we'll sync when you're back online.",
        cause: error,
        kind: FailureKind.network,
      );
    }
    if (error is FileSystemException) {
      return AppFailure(
        "We couldn't save to your device's storage. Check that there's free space and try again.",
        cause: error,
        kind: FailureKind.storage,
      );
    }
    return AppFailure(genericMessage, cause: error);
  }

  static AppFailure _fromAuth(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => "That email address doesn't look right.",
      'user-disabled' => 'This account has been disabled. Contact support for help.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        "Email or password doesn't match. Please try again.",
      'email-already-in-use' =>
        'An account with this email already exists. Try signing in instead.',
      'weak-password' =>
        'Please choose a stronger password — at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        "We can't reach the server. Check your connection and try again.",
      'requires-recent-login' =>
        'For your security, please sign in again before doing this.',
      'account-exists-with-different-credential' =>
        'This email is already linked to a different sign-in method.',
      'operation-not-allowed' =>
        "This sign-in method isn't enabled yet.",
      _ => "We couldn't sign you in. Please try again.",
    };
    return AppFailure(message, cause: e, kind: FailureKind.auth);
  }

  static AppFailure _fromFirebase(FirebaseException e) {
    final message = switch (e.code) {
      'unavailable' || 'deadline-exceeded' =>
        "We can't reach the server right now. Your data is safe on this device and will sync later.",
      'permission-denied' || 'unauthorized' =>
        "You don't have access to this. Try signing out and back in.",
      'quota-exceeded' || 'resource-exhausted' =>
        'The service is busy. Please try again shortly.',
      'object-not-found' || 'not-found' => "We couldn't find that item.",
      _ => genericMessage,
    };
    return AppFailure(message, cause: e, kind: FailureKind.server);
  }
}

enum FailureKind { unknown, auth, network, server, storage, import }

enum ImportErrorType {
  unsupportedFormat,
  plannedFormat,
  emptyBook,
  corruptedFile,
  corruptedEpub,
  drmProtected,
  tooLarge,
  noTextColumn,
}

/// Thrown by importers. Carries a type so the UI can show tailored guidance.
class ImportException implements Exception {
  const ImportException(this.type, [this.detail]);

  final ImportErrorType type;
  final String? detail;

  String get userMessage => switch (type) {
        ImportErrorType.unsupportedFormat =>
          'This file type isn\'t supported. Try an EPUB, TXT or CSV file.',
        ImportErrorType.plannedFormat =>
          'PDF support is coming soon. For now, try an EPUB or TXT version of this book.',
        ImportErrorType.emptyBook =>
          "We couldn't find any readable text in this file.",
        ImportErrorType.corruptedFile =>
          'This file seems to be damaged or incomplete. Try exporting it again.',
        ImportErrorType.corruptedEpub =>
          "This EPUB couldn't be opened. It may be damaged or use an unusual structure.",
        ImportErrorType.drmProtected =>
          'This book is DRM-protected, so its text can\'t be read by other apps.',
        ImportErrorType.tooLarge =>
          'This file is too large to import. Try a file under 60 MB.',
        ImportErrorType.noTextColumn =>
          "We couldn't find a column with text in this CSV.",
      };

  @override
  String toString() => 'ImportException($type${detail == null ? '' : ': $detail'})';
}
