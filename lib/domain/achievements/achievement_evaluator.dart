import '../models/achievement.dart';
import '../stats/reading_stats.dart';
import 'achievement_catalog.dart';

abstract final class AchievementEvaluator {
  static int valueFor(AchievementMetric metric, ReadingStats stats) => switch (metric) {
        AchievementMetric.totalWords => stats.totalWords,
        AchievementMetric.sessions => stats.sessionsCount,
        AchievementMetric.highestWpm => stats.highestWpm,
        AchievementMetric.booksCompleted => stats.booksCompleted,
        AchievementMetric.longestStreak => stats.streak.longest,
        AchievementMetric.totalSeconds => stats.totalSeconds,
      };

  /// Achievement ids whose thresholds are met by [stats].
  static Set<String> earned(ReadingStats stats) => {
        for (final a in AchievementCatalog.all)
          if (valueFor(a.metric, stats) >= a.threshold) a.id,
      };

  static List<AchievementProgress> progress(
    ReadingStats stats,
    Map<String, UnlockedAchievement> unlocked,
  ) =>
      [
        for (final a in AchievementCatalog.all)
          AchievementProgress(
            definition: a,
            current: valueFor(a.metric, stats),
            unlocked: unlocked[a.id],
          ),
      ];
}
