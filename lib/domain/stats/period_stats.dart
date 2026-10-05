import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../models/book.dart';
import '../models/reading_session.dart';

enum StatsPeriod {
  today('Today'),
  week('This Week'),
  month('This Month'),
  allTime('All Time');

  const StatsPeriod(this.label);
  final String label;
}

class ChartPoint {
  const ChartPoint(this.label, this.value);

  /// Empty labels are skipped on the axis to keep charts readable.
  final String label;
  final double value;
}

class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.totalSeconds,
    required this.totalWords,
    required this.sessions,
    required this.booksCompleted,
    required this.averageWpm,
    required this.highestWpm,
    required this.averageSessionSeconds,
    required this.longestSessionSeconds,
    required this.wordsSeries,
    required this.minutesSeries,
    required this.wpmSeries,
    required this.booksSeries,
  });

  final StatsPeriod period;
  final int totalSeconds;
  final int totalWords;
  final int sessions;
  final int booksCompleted;
  final int averageWpm;
  final int highestWpm;
  final int averageSessionSeconds;
  final int longestSessionSeconds;
  final List<ChartPoint> wordsSeries;
  final List<ChartPoint> minutesSeries;
  final List<ChartPoint> wpmSeries;
  final List<ChartPoint> booksSeries;

  bool get hasData => sessions > 0 || booksCompleted > 0;
}

abstract final class PeriodStatsCalculator {
  static const int maxWpmPoints = 30;
  static const int monthDays = 30;
  static const int allTimeMaxMonths = 12;

  static PeriodStats compute({
    required StatsPeriod period,
    required List<ReadingSession> sessions,
    required List<Book> books,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final buckets = _buckets(period, reference, sessions);
    final start = buckets.first.start;
    final end = buckets.last.end;

    bool inRange(DateTime t) => !t.isBefore(start) && t.isBefore(end);

    final inPeriod = sessions.where((s) => inRange(s.startTime)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final completedBooks =
        books.where((b) => b.completed && b.completedAt != null && inRange(b.completedAt!)).toList();

    var seconds = 0;
    var words = 0;
    var weighted = 0.0;
    var highest = 0;
    var longest = 0;
    for (final s in inPeriod) {
      seconds += s.durationSeconds;
      words += s.wordsRead;
      weighted += s.averageWpm * s.durationSeconds;
      longest = math.max(longest, s.durationSeconds);
      if (s.durationSeconds >= SessionConstants.speedRecordMinSeconds) {
        highest = math.max(highest, s.averageWpm);
      }
      final bucket = _bucketFor(buckets, s.startTime);
      bucket?.seconds += s.durationSeconds;
      bucket?.words += s.wordsRead;
    }
    for (final b in completedBooks) {
      _bucketFor(buckets, b.completedAt!)?.books += 1;
    }

    final wpmSessions = inPeriod.length > maxWpmPoints
        ? inPeriod.sublist(inPeriod.length - maxWpmPoints)
        : inPeriod;

    return PeriodStats(
      period: period,
      totalSeconds: seconds,
      totalWords: words,
      sessions: inPeriod.length,
      booksCompleted: completedBooks.length,
      averageWpm: seconds == 0 ? 0 : (weighted / seconds).round(),
      highestWpm: highest,
      averageSessionSeconds: inPeriod.isEmpty ? 0 : (seconds / inPeriod.length).round(),
      longestSessionSeconds: longest,
      wordsSeries: [for (final b in buckets) ChartPoint(b.label, b.words.toDouble())],
      minutesSeries: [for (final b in buckets) ChartPoint(b.label, b.seconds / 60)],
      wpmSeries: [
        for (final s in wpmSessions) ChartPoint(Formatters.shortDate(s.startTime), s.averageWpm.toDouble()),
      ],
      booksSeries: [for (final b in buckets) ChartPoint(b.label, b.books.toDouble())],
    );
  }

  static _Bucket? _bucketFor(List<_Bucket> buckets, DateTime t) {
    for (final b in buckets) {
      if (!t.isBefore(b.start) && t.isBefore(b.end)) return b;
    }
    return null;
  }

  static List<_Bucket> _buckets(StatsPeriod period, DateTime now, List<ReadingSession> sessions) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case StatsPeriod.today:
        return [
          for (var h = 0; h < 24; h++)
            _Bucket(
              DateTime(today.year, today.month, today.day, h),
              DateTime(today.year, today.month, today.day, h + 1),
              h % 6 == 0 ? '${h.toString().padLeft(2, '0')}:00' : '',
            ),
        ];
      case StatsPeriod.week:
        return [
          for (var i = 6; i >= 0; i--)
            _Bucket(
              DateTime(today.year, today.month, today.day - i),
              DateTime(today.year, today.month, today.day - i + 1),
              Formatters.weekday(DateTime(today.year, today.month, today.day - i)),
            ),
        ];
      case StatsPeriod.month:
        return [
          for (var i = monthDays - 1; i >= 0; i--)
            _Bucket(
              DateTime(today.year, today.month, today.day - i),
              DateTime(today.year, today.month, today.day - i + 1),
              i % 7 == 0 ? Formatters.shortDate(DateTime(today.year, today.month, today.day - i)) : '',
            ),
        ];
      case StatsPeriod.allTime:
        var first = DateTime(today.year, today.month);
        for (final s in sessions) {
          final m = DateTime(s.startTime.year, s.startTime.month);
          if (m.isBefore(first)) first = m;
        }
        final months = (today.year - first.year) * 12 + today.month - first.month + 1;
        final count = months.clamp(1, allTimeMaxMonths);
        // Earliest bucket absorbs everything older so totals stay "all time".
        return [
          for (var i = count - 1; i >= 0; i--)
            _Bucket(
              i == count - 1 && months > allTimeMaxMonths
                  ? DateTime(1970)
                  : DateTime(today.year, today.month - i),
              DateTime(today.year, today.month - i + 1),
              Formatters.month(DateTime(today.year, today.month - i)),
            ),
        ];
    }
  }
}

class _Bucket {
  _Bucket(this.start, this.end, this.label);

  final DateTime start;
  final DateTime end;
  final String label;
  int seconds = 0;
  int words = 0;
  int books = 0;
}
