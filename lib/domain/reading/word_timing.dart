import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../models/book_content.dart';
import '../models/reader_settings.dart';

/// Immutable snapshot of the timing rules used by the engine.
class WordTimingConfig {
  const WordTimingConfig({
    this.punctuationPauses = true,
    this.clauseMultiplier = ReaderConstants.defaultClauseMultiplier,
    this.sentencePauses = true,
    this.sentenceMultiplier = ReaderConstants.defaultSentenceMultiplier,
    this.paragraphPauses = true,
    this.paragraphMultiplier = ReaderConstants.defaultParagraphMultiplier,
    this.longWordAdjustment = true,
  });

  static const WordTimingConfig standard = WordTimingConfig(
    punctuationPauses: false,
    sentencePauses: false,
    paragraphPauses: false,
    longWordAdjustment: false,
  );

  factory WordTimingConfig.fromSettings(ReaderSettings s) => WordTimingConfig(
        punctuationPauses: s.punctuationPauses,
        clauseMultiplier: s.clauseMultiplier,
        sentencePauses: s.sentencePauses,
        sentenceMultiplier: s.sentenceMultiplier,
        paragraphPauses: s.paragraphPauses,
        paragraphMultiplier: s.paragraphMultiplier,
        longWordAdjustment: s.longWordAdjustment,
      );

  final bool punctuationPauses;
  final double clauseMultiplier;
  final bool sentencePauses;
  final double sentenceMultiplier;
  final bool paragraphPauses;
  final double paragraphMultiplier;
  final bool longWordAdjustment;
}

abstract final class WordTiming {
  static const int microsPerMinute = 60 * 1000 * 1000;

  /// millisecondsPerWord = 60000 / WPM, expressed in microseconds for
  /// precise scheduling.
  static double baseMicros(double wpm) => microsPerMinute / wpm;

  static double multiplier(String word, int flags, WordTimingConfig config) {
    var m = 1.0;
    if (config.paragraphPauses && flags & WordFlags.paragraphEnd != 0) {
      m = math.max(m, config.paragraphMultiplier);
    }
    if (config.sentencePauses && flags & WordFlags.sentenceEnd != 0) {
      m = math.max(m, config.sentenceMultiplier);
    }
    if (config.punctuationPauses && flags & WordFlags.clauseEnd != 0) {
      m = math.max(m, config.clauseMultiplier);
    }
    if (config.longWordAdjustment && word.length > ReaderConstants.longWordThreshold) {
      final extra = (word.length - ReaderConstants.longWordThreshold) *
          ReaderConstants.longWordStepMultiplier;
      m *= math.min(ReaderConstants.maxLongWordMultiplier, 1 + extra);
    }
    return m;
  }

  static int durationMicros(String word, int flags, double wpm, WordTimingConfig config) =>
      (baseMicros(wpm) * multiplier(word, flags, config)).round();
}
