/// Estimates when a book finishes if the reader keeps a daily minute goal.
abstract final class ReadingPace {
  static int? daysRemaining({
    required int wordsRemaining,
    required int wpm,
    required int minutesPerDay,
  }) {
    if (wordsRemaining <= 0 || wpm <= 0 || minutesPerDay <= 0) return null;
    final wordsPerDay = wpm * minutesPerDay;
    if (wordsPerDay <= 0) return null;
    final ratio = wordsRemaining / wordsPerDay;
    if (ratio <= 1) return 0;
    return (ratio - 1e-9).floor();
  }

  static DateTime? finishOn({
    required int wordsRemaining,
    required int wpm,
    required int minutesPerDay,
    DateTime? from,
  }) {
    final days = daysRemaining(wordsRemaining: wordsRemaining, wpm: wpm, minutesPerDay: minutesPerDay);
    if (days == null) return null;
    final start = from ?? DateTime.now();
    return DateTime(start.year, start.month, start.day).add(Duration(days: days));
  }
}
