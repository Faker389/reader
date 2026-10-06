import 'wpm_scale.dart';

/// Decides whether a saved reading speed should move one step.
///
/// Easy sessions (few retraces) step up. Sessions with a lot of rewinding,
/// or a comprehension check that mostly missed, step down.
abstract final class TrainingPace {
  static int fromSession({required int current, required int wordsRead, required int retraces}) {
    if (wordsRead < 80) return current;
    if (retraces >= 3) return WpmScale.step(current, -1);
    if (retraces <= 1) return WpmScale.step(current, 1);
    return current;
  }

  static int fromQuiz({required int current, required int correct, required int asked}) {
    if (asked <= 0) return current;
    if (correct == asked) return WpmScale.step(current, 1);
    if (correct * 2 < asked) return WpmScale.step(current, -1);
    return current;
  }
}
