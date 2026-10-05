/// Optimal recognition point: the character the eye should fixate on. Placed
/// slightly left of centre, which is where readers naturally fixate a word.
abstract final class FocalPoint {
  static const String _leading = '"\'“‘([{«‹*_-—–';

  static int indexFor(String word) {
    var start = 0;
    while (start < word.length - 1 && _leading.contains(word[start])) {
      start++;
    }
    var end = word.length;
    while (end > start + 1 && !_isLetterOrDigit(word.codeUnitAt(end - 1))) {
      end--;
    }
    final length = end - start;
    final int offset;
    if (length <= 1) {
      offset = 0;
    } else if (length <= 5) {
      offset = 1;
    } else if (length <= 9) {
      offset = 2;
    } else if (length <= 13) {
      offset = 3;
    } else {
      offset = 4;
    }
    var index = start + offset;
    // Never split a surrogate pair.
    if (index > 0 && index < word.length && _isLowSurrogate(word.codeUnitAt(index))) {
      index--;
    }
    return index.clamp(0, word.isEmpty ? 0 : word.length - 1);
  }

  /// Length in UTF-16 units of the focal character at [index].
  static int focalLength(String word, int index) {
    if (index + 1 < word.length && _isHighSurrogate(word.codeUnitAt(index))) return 2;
    return 1;
  }

  static bool _isLetterOrDigit(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c >= 0xC0;

  static bool _isHighSurrogate(int c) => c >= 0xD800 && c <= 0xDBFF;
  static bool _isLowSurrogate(int c) => c >= 0xDC00 && c <= 0xDFFF;
}
