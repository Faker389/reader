import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract interface class CrashReporter {
  void recordNonFatal(Object error, StackTrace? stack, {String? reason});
  void recordFatal(Object error, StackTrace? stack);
  Future<void> setUser(String? uid);
}

class DebugCrashReporter implements CrashReporter {
  const DebugCrashReporter();

  @override
  void recordNonFatal(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('[non-fatal${reason == null ? '' : ' $reason'}] $error');
  }

  @override
  void recordFatal(Object error, StackTrace? stack) {
    debugPrint('[fatal] $error\n$stack');
  }

  @override
  Future<void> setUser(String? uid) async {}
}

class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter([FirebaseCrashlytics? crashlytics])
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  void recordNonFatal(Object error, StackTrace? stack, {String? reason}) {
    if (kDebugMode) debugPrint('[non-fatal${reason == null ? '' : ' $reason'}] $error');
    _crashlytics.recordError(error, stack, reason: reason);
  }

  @override
  void recordFatal(Object error, StackTrace? stack) {
    _crashlytics.recordError(error, stack, fatal: true);
  }

  /// Only the opaque uid is attached — never names or emails.
  @override
  Future<void> setUser(String? uid) => _crashlytics.setUserIdentifier(uid ?? '');
}
