/// App-wide configuration values. Anything tunable lives here rather than
/// being scattered through widgets and services as magic numbers.
library;

abstract final class AppInfo {
  static const String name = 'Fovea';
  static const String tagline = 'One word. Full focus.';
  static const String supportEmail = 'support@fovea.app';
}

abstract final class ReaderConstants {
  static const int minWpm = 50;
  static const int maxWpm = 1200;
  static const int defaultWpm = 250;

  /// Words skipped by the back/forward buttons and horizontal swipes.
  static const int skipWordCount = 10;

  static const Duration controlsAutoHideDelay = Duration(seconds: 3);
  static const Duration progressPersistInterval = Duration(seconds: 5);

  // Intelligent timing defaults (multipliers of the base word duration).
  static const double defaultClauseMultiplier = 1.25;
  static const double defaultSentenceMultiplier = 1.5;
  static const double defaultParagraphMultiplier = 2.0;
  static const double minPauseMultiplier = 1.0;
  static const double maxPauseMultiplier = 3.0;

  /// Words longer than this receive a gradual extra display time.
  static const int longWordThreshold = 8;
  static const double longWordStepMultiplier = 0.04;
  static const double maxLongWordMultiplier = 1.5;

  /// Fraction of the gap between current and target speed that is closed on
  /// every word, producing a smooth exponential ramp after a WPM change.
  static const double wpmRampFactor = 0.18;

  /// After pressing play, the first few words start slightly slower and ease
  /// into full speed so the reader can lock on to the focal point.
  static const int resumeWarmupWords = 6;
  static const double resumeWarmupStartFactor = 0.7;

  /// If the engine falls behind (jank, backgrounding), a word is still shown
  /// for at least this fraction of its intended duration.
  static const double minDisplayFraction = 0.5;

  static const int contextWordsWhenPaused = 7;

  static const double minFontScale = 0.7;
  static const double maxFontScale = 1.6;
  static const double baseWordSizeFactor = 0.115;
  static const double maxBaseWordSize = 72;
  static const double tabletBaseWordSize = 96;

  static const double minSwipeVelocity = 250;
}

abstract final class WpmPreset {
  static const int slow = 150;
  static const int comfortable = 250;
  static const int fast = 400;
  static const int veryFast = 600;
}

abstract final class SessionConstants {
  /// Default minimum active reading time before a session is recorded.
  static const int defaultMinMeaningfulSeconds = 30;
  static const List<int> minMeaningfulOptions = [15, 30, 60, 120];

  /// Sessions shorter than this don't count towards "highest WPM" so that
  /// briefly tapping + doesn't unlock speed achievements.
  static const int speedRecordMinSeconds = 60;

  /// Upper bound used to reject implausible session data.
  static const int maxPlausibleWpm = 1500;
  static const int maxSessionSeconds = 6 * 60 * 60;
}

abstract final class GoalConstants {
  static const List<int> dailyMinuteOptions = [10, 20, 30, 45, 60];
  static const int defaultDailyMinutes = 20;
  static const List<int> startingWpmOptions = [150, 200, 250, 300, 400, 500];
}

abstract final class ImportConstants {
  static const List<String> supportedExtensions = ['txt', 'epub', 'csv'];
  static const List<String> plannedExtensions = ['pdf'];
  static const int maxFileBytes = 60 * 1024 * 1024;
  static const int maxTitleLength = 160;
  static const int maxAuthorLength = 120;
  static const int maxChapterTitleLength = 120;
  static const int csvPreviewRows = 6;

  /// Single-word CSV rows are grouped into paragraphs of this many words.
  static const int csvWordsPerParagraph = 120;
  static const int minChapterWords = 3;
}

abstract final class NotificationConstants {
  static const int dailyReminderId = 1001;
  static const String channelId = 'reading_reminders';
  static const String channelName = 'Reading reminders';
  static const String channelDescription =
      'Gentle daily reminders for your reading goal.';
  static const int defaultReminderHour = 20;
  static const int defaultReminderMinute = 0;
}

abstract final class MotionConstants {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration celebration = Duration(milliseconds: 900);
  static const double pressedScale = 0.97;
}

abstract final class LayoutConstants {
  static const double pagePadding = 20;
  static const double cardRadius = 24;
  static const double smallRadius = 14;
  static const double tabletBreakpoint = 700;
  static const double maxContentWidth = 720;
  static const double bottomNavHeight = 68;
}
