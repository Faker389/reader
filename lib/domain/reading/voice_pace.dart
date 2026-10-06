import 'dart:math' as math;

/// Decides when on-screen words can be spoken, and how fast.
///
/// Speech needs a moment to start and to be heard. Once the words leave the
/// screen sooner than that, the voice stays quiet instead of talking over
/// the next words.
abstract final class VoicePace {
  /// Shortest time a chunk can stay up and still be said.
  static const int minDisplayMicros = 180000;

  static bool canSpeak(int displayMicros) => displayMicros >= minDisplayMicros;

  /// Rate relative to an ordinary speaking pace of about 160 words per minute.
  /// Kept inside a range that still sounds like speech.
  static double rateFor(int wpm) {
    if (wpm <= 0) return 1;
    return (wpm / 160).clamp(0.75, 1.65);
  }

  /// The words currently held on the focal point.
  static String phrase(List<String> words, int index, int chunkSize) {
    if (words.isEmpty || index < 0 || index >= words.length) return '';
    final count = chunkSize.clamp(1, 3);
    final end = math.min(words.length, index + count);
    return words.sublist(index, end).join(' ');
  }
}
