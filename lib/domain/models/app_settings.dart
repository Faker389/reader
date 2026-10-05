import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';
import 'reader_settings.dart';

enum AppThemePreference {
  dark('Dark'),
  light('Light'),
  system('System');

  const AppThemePreference(this.label);
  final String label;
}

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = false,
    this.hour = NotificationConstants.defaultReminderHour,
    this.minute = NotificationConstants.defaultReminderMinute,
    this.goalReminders = true,
    this.streakReminders = true,
    this.continueReminders = true,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final bool goalReminders;
  final bool streakReminders;
  final bool continueReminders;

  NotificationPreferences copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? goalReminders,
    bool? streakReminders,
    bool? continueReminders,
  }) =>
      NotificationPreferences(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        goalReminders: goalReminders ?? this.goalReminders,
        streakReminders: streakReminders ?? this.streakReminders,
        continueReminders: continueReminders ?? this.continueReminders,
      );

  JsonMap toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'goalReminders': goalReminders,
        'streakReminders': streakReminders,
        'continueReminders': continueReminders,
      };

  factory NotificationPreferences.fromJson(JsonMap json) {
    const d = NotificationPreferences();
    return NotificationPreferences(
      enabled: json.boolean('enabled', d.enabled),
      hour: json.integer('hour', d.hour).clamp(0, 23),
      minute: json.integer('minute', d.minute).clamp(0, 59),
      goalReminders: json.boolean('goalReminders', d.goalReminders),
      streakReminders: json.boolean('streakReminders', d.streakReminders),
      continueReminders: json.boolean('continueReminders', d.continueReminders),
    );
  }
}

/// Device-level preferences. Stored locally; reading-related defaults are also
/// mirrored to the user profile so they follow the user across devices.
class AppSettings {
  const AppSettings({
    this.theme = AppThemePreference.dark,
    this.largeText = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.analyticsEnabled = true,
    this.minSessionSeconds = SessionConstants.defaultMinMeaningfulSeconds,
    this.notifications = const NotificationPreferences(),
    this.reader = const ReaderSettings(),
  });

  final AppThemePreference theme;
  final bool largeText;
  final bool highContrast;
  final bool reduceMotion;
  final bool analyticsEnabled;
  final int minSessionSeconds;
  final NotificationPreferences notifications;
  final ReaderSettings reader;

  AppSettings copyWith({
    AppThemePreference? theme,
    bool? largeText,
    bool? highContrast,
    bool? reduceMotion,
    bool? analyticsEnabled,
    int? minSessionSeconds,
    NotificationPreferences? notifications,
    ReaderSettings? reader,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        largeText: largeText ?? this.largeText,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
        minSessionSeconds: minSessionSeconds ?? this.minSessionSeconds,
        notifications: notifications ?? this.notifications,
        reader: reader ?? this.reader,
      );

  JsonMap toJson() => {
        'theme': theme.name,
        'largeText': largeText,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'analyticsEnabled': analyticsEnabled,
        'minSessionSeconds': minSessionSeconds,
        'notifications': notifications.toJson(),
        'reader': reader.toJson(),
      };

  factory AppSettings.fromJson(JsonMap json) {
    const d = AppSettings();
    final notifications = json['notifications'];
    final reader = json['reader'];
    return AppSettings(
      theme: json.enumValue('theme', AppThemePreference.values, d.theme),
      largeText: json.boolean('largeText', d.largeText),
      highContrast: json.boolean('highContrast', d.highContrast),
      reduceMotion: json.boolean('reduceMotion', d.reduceMotion),
      analyticsEnabled: json.boolean('analyticsEnabled', d.analyticsEnabled),
      minSessionSeconds: json.integer('minSessionSeconds', d.minSessionSeconds),
      notifications: notifications is Map
          ? NotificationPreferences.fromJson(Map<String, dynamic>.from(notifications))
          : d.notifications,
      reader: reader is Map ? ReaderSettings.fromJson(Map<String, dynamic>.from(reader)) : d.reader,
    );
  }
}

/// Choices made during onboarding, before an account exists.
class OnboardingChoices {
  const OnboardingChoices({
    this.completed = false,
    this.goalMinutes = GoalConstants.defaultDailyMinutes,
    this.startingWpm = ReaderConstants.defaultWpm,
  });

  final bool completed;
  final int goalMinutes;
  final int startingWpm;

  JsonMap toJson() => {
        'completed': completed,
        'goalMinutes': goalMinutes,
        'startingWpm': startingWpm,
      };

  factory OnboardingChoices.fromJson(JsonMap json) => OnboardingChoices(
        completed: json.boolean('completed'),
        goalMinutes: json.integer('goalMinutes', GoalConstants.defaultDailyMinutes),
        startingWpm: json.integer('startingWpm', ReaderConstants.defaultWpm),
      );
}
