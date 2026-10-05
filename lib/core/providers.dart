import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/file_store.dart';
import '../data/local/local_database.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporter.dart';
import '../services/notification_service.dart';

/// Infrastructure created during bootstrap and injected via overrides.
class AppEnvironment {
  const AppEnvironment({
    required this.firebaseAvailable,
    required this.database,
    required this.files,
    required this.analytics,
    required this.crash,
    required this.notifications,
  });

  final bool firebaseAvailable;
  final LocalDatabase database;
  final FileStore files;
  final AnalyticsService analytics;
  final CrashReporter crash;
  final NotificationService notifications;
}

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError('appEnvironmentProvider must be overridden in bootstrap'),
);

final firebaseAvailableProvider = Provider<bool>((ref) => ref.watch(appEnvironmentProvider).firebaseAvailable);
final localDatabaseProvider = Provider<LocalDatabase>((ref) => ref.watch(appEnvironmentProvider).database);
final fileStoreProvider = Provider<FileStore>((ref) => ref.watch(appEnvironmentProvider).files);
final analyticsProvider = Provider<AnalyticsService>((ref) => ref.watch(appEnvironmentProvider).analytics);
final crashReporterProvider = Provider<CrashReporter>((ref) => ref.watch(appEnvironmentProvider).crash);
final notificationServiceProvider =
    Provider<NotificationService>((ref) => ref.watch(appEnvironmentProvider).notifications);
