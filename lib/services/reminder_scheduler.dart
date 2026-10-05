import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../domain/reminders/reminder_planner.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/statistics/application/stats_providers.dart';
import 'crash_reporter.dart';
import 'notification_service.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => ReminderScheduler(ref));

/// Re-plans the single upcoming reminder from the latest settings and stats.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  NotificationService get _notifications => _ref.read(notificationServiceProvider);
  CrashReporter get _crash => _ref.read(crashReporterProvider);

  Future<void> reschedule() async {
    try {
      final prefs = _ref.read(settingsControllerProvider).notifications;
      if (!prefs.enabled) {
        await _notifications.cancelAll();
        return;
      }
      final stats = _ref.read(readingStatsProvider);
      final message = ReminderPlanner.plan(
        prefs: prefs,
        stats: stats,
        goalMinutes: _ref.read(goalMinutesProvider),
        continueBookTitle: _ref.read(continueBookProvider)?.title,
      );
      if (message == null) {
        await _notifications.cancelAll();
        return;
      }
      await _notifications.scheduleNext(
        message: message,
        hour: prefs.hour,
        minute: prefs.minute,
        skipToday: stats.streak.todayMet,
      );
    } on Object catch (e, s) {
      _crash.recordNonFatal(e, s, reason: 'reminders');
    }
  }
}
