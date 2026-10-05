import '../models/achievement.dart';

/// The single source of truth for achievement rules on the client. The same
/// ids and thresholds are mirrored in `functions/src/achievements.ts`, which is
/// authoritative.
abstract final class AchievementCatalog {
  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: 'first_words',
      title: 'First Words',
      description: 'Read your first 1,000 words.',
      metric: AchievementMetric.totalWords,
      threshold: 1000,
      glyph: AchievementGlyph.spark,
      unit: 'words',
    ),
    AchievementDefinition(
      id: 'getting_started',
      title: 'Getting Started',
      description: 'Complete your first reading session.',
      metric: AchievementMetric.sessions,
      threshold: 1,
      glyph: AchievementGlyph.play,
      unit: 'sessions',
    ),
    AchievementDefinition(
      id: 'speed_reader',
      title: 'Speed Reader',
      description: 'Sustain 300 WPM for a full session.',
      metric: AchievementMetric.highestWpm,
      threshold: 300,
      glyph: AchievementGlyph.gauge,
      unit: 'WPM',
    ),
    AchievementDefinition(
      id: 'fast_lane',
      title: 'Fast Lane',
      description: 'Sustain 500 WPM for a full session.',
      metric: AchievementMetric.highestWpm,
      threshold: 500,
      glyph: AchievementGlyph.bolt,
      unit: 'WPM',
    ),
    AchievementDefinition(
      id: 'lightning',
      title: 'Lightning',
      description: 'Sustain 750 WPM for a full session.',
      metric: AchievementMetric.highestWpm,
      threshold: 750,
      glyph: AchievementGlyph.lightning,
      unit: 'WPM',
    ),
    AchievementDefinition(
      id: 'bookworm',
      title: 'Bookworm',
      description: 'Read 100,000 words.',
      metric: AchievementMetric.totalWords,
      threshold: 100000,
      glyph: AchievementGlyph.book,
      unit: 'words',
    ),
    AchievementDefinition(
      id: 'million_words',
      title: 'Million Words',
      description: 'Read 1,000,000 words.',
      metric: AchievementMetric.totalWords,
      threshold: 1000000,
      glyph: AchievementGlyph.crown,
      unit: 'words',
    ),
    AchievementDefinition(
      id: 'first_book',
      title: 'First Book',
      description: 'Finish your first book.',
      metric: AchievementMetric.booksCompleted,
      threshold: 1,
      glyph: AchievementGlyph.library,
      unit: 'books',
    ),
    AchievementDefinition(
      id: 'three_books',
      title: 'Three Books',
      description: 'Finish 3 books.',
      metric: AchievementMetric.booksCompleted,
      threshold: 3,
      glyph: AchievementGlyph.mountain,
      unit: 'books',
    ),
    AchievementDefinition(
      id: 'streak_7',
      title: '7 Day Streak',
      description: 'Meet your daily goal 7 days in a row.',
      metric: AchievementMetric.longestStreak,
      threshold: 7,
      glyph: AchievementGlyph.flame,
      unit: 'days',
    ),
    AchievementDefinition(
      id: 'streak_30',
      title: '30 Day Streak',
      description: 'Meet your daily goal 30 days in a row.',
      metric: AchievementMetric.longestStreak,
      threshold: 30,
      glyph: AchievementGlyph.flame,
      unit: 'days',
    ),
    AchievementDefinition(
      id: 'ten_hours',
      title: '10 Hours',
      description: 'Read for 10 hours in total.',
      metric: AchievementMetric.totalSeconds,
      threshold: 10 * 60 * 60,
      glyph: AchievementGlyph.clock,
      unit: 'hours',
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
