import 'package:intl/intl.dart';

/// Human-friendly formatting shared by every screen so numbers and durations
/// look identical throughout the app.
abstract final class Formatters {
  static final NumberFormat _grouped = NumberFormat.decimalPattern();
  static final NumberFormat _compact = NumberFormat.compact();

  static String number(num value) => _grouped.format(value);

  static String compact(num value) =>
      value < 10000 ? _grouped.format(value) : _compact.format(value);

  static String percent(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (clamped > 0 && clamped < 0.01) return '<1%';
    return '${(clamped * 100).floor()}%';
  }

  /// "1h 24m", "18m", "45s".
  static String duration(Duration d) {
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      return minutes == 0 ? '${d.inHours}h' : '${d.inHours}h ${minutes}m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  /// "12 min 42 sec" — used on the session summary where precision matters.
  static String durationLong(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '$hours h $minutes min';
    if (minutes > 0) return '$minutes min $seconds sec';
    return '$seconds sec';
  }

  /// "04:12" or "1:04:12" for the live reader clock.
  static String clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  static String minutes(int totalSeconds) => '${(totalSeconds / 60).round()}';

  static String relativeDate(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Never opened';
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${(diff / 7).floor()} wk ago';
    return DateFormat.yMMMd().format(date);
  }

  static String shortDate(DateTime date) => DateFormat.MMMd().format(date);
  static String weekday(DateTime date) => DateFormat.E().format(date);
  static String month(DateTime date) => DateFormat.MMM().format(date);
}

/// Date keys are local calendar days ("2026-10-04"). Using strings rather than
/// DateTime avoids daylight-saving and timezone surprises in streak maths.
abstract final class DayKey {
  static String of(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static DateTime parse(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static String shift(String key, int days) {
    final date = parse(key);
    return of(DateTime(date.year, date.month, date.day + days));
  }

  static String today() => of(DateTime.now());
}
