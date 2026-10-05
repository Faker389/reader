import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../models/book.dart';
import '../models/reading_session.dart';

class DayTotal {
  const DayTotal({
    required this.seconds,
    required this.words,
    required this.sessions,
    required this.goalMinutes,
  });

  final int seconds;
  final int words;
  final int sessions;
  final int goalMinutes;

  bool get goalMet => seconds >= goalMinutes * 60;
}

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.longest,
    required this.todayMet,
    required this.lastMetDay,
  });

  static const StreakInfo empty =
      StreakInfo(current: 0, longest: 0, todayMet: false, lastMetDay: null);

  final int current;
  final int longest;
  final bool todayMet;
  final String? lastMetDay;

  /// The streak is alive but today's goal hasn't been met yet.
  bool get pendingToday => current > 0 && !todayMet;
}

/// Lifetime aggregates derived from sessions. The same maths runs in the
/// Cloud Function so the server can verify what the client displays.
class ReadingStats {
  const ReadingStats({
    required this.totalSeconds,
    required this.totalWords,
    required this.sessionsCount,
    required this.booksCompleted,
    required this.averageWpm,
    required this.highestWpm,
    required this.averageSessionSeconds,
    required this.longestSessionSeconds,
    required this.streak,
    required this.days,
    required this.speedImprovement,
    required this.firstSessionAt,
  });

  static const ReadingStats empty = ReadingStats(
    totalSeconds: 0,
    totalWords: 0,
    sessionsCount: 0,
    booksCompleted: 0,
    averageWpm: 0,
    highestWpm: 0,
    averageSessionSeconds: 0,
    longestSessionSeconds: 0,
    streak: StreakInfo.empty,
    days: {},
    speedImprovement: null,
    firstSessionAt: null,
  );

  final int totalSeconds;
  final int totalWords;
  final int sessionsCount;
  final int booksCompleted;
  final int averageWpm;
  final int highestWpm;
  final int averageSessionSeconds;
  final int longestSessionSeconds;
  final StreakInfo streak;
  final Map<String, DayTotal> days;

  /// Relative change between early and recent average speed, or null when
  /// there isn't enough data to make an honest comparison.
  final double? speedImprovement;
  final DateTime? firstSessionAt;

  bool get hasData => sessionsCount > 0;

  DayTotal today() => days[DayKey.today()] ?? const DayTotal(seconds: 0, words: 0, sessions: 0, goalMinutes: 0);
}

abstract final class StatsCalculator {
  /// Sessions compared at each end of the history for the speed insight.
  static const int improvementSampleSize = 3;
  static const double minMeaningfulImprovement = 0.05;

  static ReadingStats compute({
    required List<ReadingSession> sessions,
    required List<Book> books,
    required int currentGoalMinutes,
    DateTime? now,
  }) {
    if (sessions.isEmpty) {
      final completed = books.where((b) => b.completed).length;
      return completed == 0
          ? ReadingStats.empty
          : _withBooks(ReadingStats.empty, completed);
    }

    final sorted = [...sessions]..sort((a, b) => a.startTime.compareTo(b.startTime));
    var totalSeconds = 0;
    var totalWords = 0;
    var wpmTimeWeighted = 0.0;
    var highest = 0;
    var longest = 0;
    final dayAccumulator = <String, _DayAcc>{};

    for (final s in sorted) {
      totalSeconds += s.durationSeconds;
      totalWords += s.wordsRead;
      wpmTimeWeighted += s.averageWpm * s.durationSeconds;
      longest = math.max(longest, s.durationSeconds);
      if (s.durationSeconds >= SessionConstants.speedRecordMinSeconds) {
        highest = math.max(highest, s.averageWpm);
      }
      final acc = dayAccumulator.putIfAbsent(s.localDate, _DayAcc.new);
      acc
        ..seconds += s.durationSeconds
        ..words += s.wordsRead
        ..sessions += 1
        ..goalMinutes = s.goalMinutes;
    }

    final days = {
      for (final entry in dayAccumulator.entries)
        entry.key: DayTotal(
          seconds: entry.value.seconds,
          words: entry.value.words,
          sessions: entry.value.sessions,
          goalMinutes: entry.value.goalMinutes,
        ),
    };

    return ReadingStats(
      totalSeconds: totalSeconds,
      totalWords: totalWords,
      sessionsCount: sorted.length,
      booksCompleted: books.where((b) => b.completed).length,
      averageWpm: totalSeconds == 0 ? 0 : (wpmTimeWeighted / totalSeconds).round(),
      highestWpm: highest,
      averageSessionSeconds: (totalSeconds / sorted.length).round(),
      longestSessionSeconds: longest,
      streak: StreakCalculator.compute(days, currentGoalMinutes: currentGoalMinutes, now: now),
      days: days,
      speedImprovement: _improvement(sorted),
      firstSessionAt: sorted.first.startTime,
    );
  }

  static ReadingStats _withBooks(ReadingStats s, int completed) => ReadingStats(
        totalSeconds: s.totalSeconds,
        totalWords: s.totalWords,
        sessionsCount: s.sessionsCount,
        booksCompleted: completed,
        averageWpm: s.averageWpm,
        highestWpm: s.highestWpm,
        averageSessionSeconds: s.averageSessionSeconds,
        longestSessionSeconds: s.longestSessionSeconds,
        streak: s.streak,
        days: s.days,
        speedImprovement: s.speedImprovement,
        firstSessionAt: s.firstSessionAt,
      );

  static double? _improvement(List<ReadingSession> sorted) {
    final meaningful =
        sorted.where((s) => s.durationSeconds >= SessionConstants.speedRecordMinSeconds).toList();
    if (meaningful.length < improvementSampleSize * 2) return null;
    double avg(Iterable<ReadingSession> list) =>
        list.fold<int>(0, (sum, s) => sum + s.averageWpm) / list.length;
    final early = avg(meaningful.take(improvementSampleSize));
    final recent = avg(meaningful.skip(meaningful.length - improvementSampleSize));
    if (early <= 0) return null;
    final change = (recent - early) / early;
    return change.abs() < minMeaningfulImprovement ? null : change;
  }
}

class _DayAcc {
  int seconds = 0;
  int words = 0;
  int sessions = 0;
  int goalMinutes = 0;
}

abstract final class StreakCalculator {
  /// A day counts towards the streak when the daily goal in effect that day
  /// was met. Today not yet being met does not break the streak.
  static StreakInfo compute(
    Map<String, DayTotal> days, {
    required int currentGoalMinutes,
    DateTime? now,
  }) {
    bool met(String key) {
      final day = days[key];
      if (day == null) return false;
      final goal = day.goalMinutes > 0 ? day.goalMinutes : currentGoalMinutes;
      return day.seconds >= goal * 60;
    }

    final today = DayKey.of(now ?? DateTime.now());
    final todayMet = met(today);

    var current = 0;
    var cursor = todayMet ? today : DayKey.shift(today, -1);
    while (met(cursor)) {
      current++;
      cursor = DayKey.shift(cursor, -1);
    }

    final metDays = days.keys.where(met).toList()..sort();
    var longest = 0;
    var run = 0;
    String? previous;
    for (final key in metDays) {
      run = previous != null && DayKey.shift(previous, 1) == key ? run + 1 : 1;
      longest = math.max(longest, run);
      previous = key;
    }

    return StreakInfo(
      current: current,
      longest: math.max(longest, current),
      todayMet: todayMet,
      lastMetDay: metDays.isEmpty ? null : metDays.last,
    );
  }
}
