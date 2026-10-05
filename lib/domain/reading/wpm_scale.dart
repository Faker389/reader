import '../../core/constants/app_constants.dart';

/// The discrete WPM values a user can select:
/// 50–300 in steps of 10, 300–600 in steps of 25, 600+ in steps of 50.
abstract final class WpmScale {
  static final List<int> values = _build();

  static List<int> _build() {
    final result = <int>[];
    for (var v = ReaderConstants.minWpm; v < 300; v += 10) {
      result.add(v);
    }
    for (var v = 300; v < 600; v += 25) {
      result.add(v);
    }
    for (var v = 600; v <= ReaderConstants.maxWpm; v += 50) {
      result.add(v);
    }
    return List.unmodifiable(result);
  }

  static int clamp(int wpm) => wpm.clamp(ReaderConstants.minWpm, ReaderConstants.maxWpm);

  /// Index of the closest selectable value.
  static int indexOf(int wpm) {
    final target = clamp(wpm);
    var best = 0;
    var bestDiff = 1 << 30;
    for (var i = 0; i < values.length; i++) {
      final diff = (values[i] - target).abs();
      if (diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    return best;
  }

  static int snap(int wpm) => values[indexOf(wpm)];

  static int step(int wpm, int direction) {
    final snapped = snap(wpm);
    var index = values.indexOf(snapped);
    if (direction > 0 && snapped <= wpm) index++;
    if (direction < 0 && snapped >= wpm) index--;
    return values[index.clamp(0, values.length - 1)];
  }

  static String presetLabel(int wpm) => switch (wpm) {
        WpmPreset.slow => 'Slow',
        WpmPreset.comfortable => 'Comfortable',
        WpmPreset.fast => 'Fast',
        WpmPreset.veryFast => 'Very fast',
        _ => 'Custom',
      };
}
