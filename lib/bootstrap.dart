import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/providers.dart';
import 'data/local/file_store.dart';
import 'data/local/local_database.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/crash_reporter.dart';
import 'services/notification_service.dart';

/// Initialises infrastructure before the first frame. Firebase is optional:
/// if it isn't configured the app falls back to local-only mode instead of
/// failing to start.
Future<AppEnvironment> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseAvailable = await _initFirebase();
  final CrashReporter crash = firebaseAvailable ? FirebaseCrashReporter() : const DebugCrashReporter();
  final AnalyticsService analytics = firebaseAvailable ? FirebaseAnalyticsService() : DebugAnalyticsService();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.recordFatal(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.recordFatal(error, stack);
    return true;
  };

  final database = await LocalDatabase.open();
  final files = await FileStore.open();
  final notifications = NotificationService();
  unawaited(notifications.initialise().catchError((Object e) => debugPrint('Notifications unavailable: $e')));

  return AppEnvironment(
    firebaseAvailable: firebaseAvailable,
    database: database,
    files: files,
    analytics: analytics,
    crash: crash,
    notifications: notifications,
  );
}

Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return true;
  } on UnsupportedError {
    debugPrint('Firebase not configured — running in offline demo mode.');
    return false;
  } on Object catch (e) {
    debugPrint('Firebase failed to initialise ($e) — running in offline demo mode.');
    return false;
  }
}
