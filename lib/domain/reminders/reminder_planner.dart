import '../models/app_settings.dart';
import '../stats/reading_stats.dart';

class ReminderMessage {
  const ReminderMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Chooses at most one gentle message for the next daily reminder.
abstract final class ReminderPlanner {
  static const List<int> streakMilestones = [7, 14, 30, 60, 100];

  static ReminderMessage? plan({
    required NotificationPreferences prefs,
    required ReadingStats stats,
    required int goalMinutes,
    String? continueBookTitle,
  }) {
    if (!prefs.enabled) return null;

    final nextStreak = stats.streak.current + 1;
    if (prefs.streakReminders && streakMilestones.contains(nextStreak)) {
      return ReminderMessage(
        title: 'Almost there',
        body: "You're one session away from a $nextStreak-day streak.",
      );
    }
    if (prefs.continueReminders && continueBookTitle != null) {
      return ReminderMessage(
        title: 'Pick up where you left off',
        body: 'Continue reading $continueBookTitle.',
      );
    }
    if (prefs.goalReminders) {
      return ReminderMessage(
        title: 'A few quiet minutes',
        body: 'Your $goalMinutes-minute reading goal is waiting.',
      );
    }
    return null;
  }
}
