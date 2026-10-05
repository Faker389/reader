import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../domain/achievements/achievement_evaluator.dart';
import '../../../domain/models/achievement.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/reading_session.dart';
import '../../../domain/stats/period_stats.dart';
import '../../../domain/stats/reading_stats.dart';

/// Today's date key. Refreshed when the app resumes so "today" figures roll
/// over correctly if the app stays open past midnight.
final dayKeyProvider = NotifierProvider<DayKeyController, String>(DayKeyController.new);

class DayKeyController extends Notifier<String> {
  @override
  String build() => DayKey.today();

  void refresh() {
    final today = DayKey.today();
    if (today != state) state = today;
  }
}

final goalMinutesProvider = Provider<int>(
  (ref) =>
      ref.watch(profileProvider.select((p) => p.value?.readingGoalMinutes)) ??
      GoalConstants.defaultDailyMinutes,
);

final _sessionsListProvider =
    Provider<List<ReadingSession>>((ref) => ref.watch(sessionsProvider).value ?? const []);

final _booksListProvider = Provider<List<Book>>((ref) => ref.watch(booksProvider).value ?? const []);

final readingStatsProvider = Provider<ReadingStats>((ref) {
  ref.watch(dayKeyProvider);
  return StatsCalculator.compute(
    sessions: ref.watch(_sessionsListProvider),
    books: ref.watch(_booksListProvider),
    currentGoalMinutes: ref.watch(goalMinutesProvider),
  );
});

final periodStatsProvider = Provider.family<PeriodStats, StatsPeriod>((ref, period) {
  ref.watch(dayKeyProvider);
  return PeriodStatsCalculator.compute(
    period: period,
    sessions: ref.watch(_sessionsListProvider),
    books: ref.watch(_booksListProvider),
  );
});

final achievementProgressProvider = Provider<List<AchievementProgress>>((ref) {
  final unlocked = ref.watch(unlockedAchievementsProvider).value ?? const {};
  return AchievementEvaluator.progress(ref.watch(readingStatsProvider), unlocked);
});

/// The book shown in "Continue reading": most recently opened unfinished book.
final continueBookProvider = Provider<Book?>((ref) {
  final books = ref.watch(_booksListProvider).where((b) => b.isInProgress && b.contentAvailable).toList()
    ..sort((a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(a.lastOpenedAt ?? a.updatedAt));
  return books.isEmpty ? null : books.first;
});
