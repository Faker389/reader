/// A sentence from the passage with one word removed.
class ClozeQuestion {
  const ClozeQuestion({
    required this.before,
    required this.after,
    required this.answer,
    required this.choices,
  });

  final String before;
  final String after;
  final String answer;

  /// Includes [answer]. Order is fixed for a given passage so the check is stable.
  final List<String> choices;
}

/// Builds two or three fill-in questions from words the reader just saw.
/// Choices come from the same passage, so nothing leaves the device.
abstract final class ComprehensionQuiz {
  static const _stop = {
    'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'for', 'with', 'at', 'by', 'from',
    'as', 'is', 'was', 'were', 'be', 'been', 'are', 'it', 'its', 'that', 'this', 'these', 'those',
    'he', 'she', 'they', 'we', 'you', 'i', 'his', 'her', 'their', 'not', 'no', 'yes',
  };

  static List<ClozeQuestion> build(List<String> words, int start, int end) {
    if (words.isEmpty) return const [];
    final from = start.clamp(0, words.length);
    final to = end.clamp(from, words.length);
    if (to - from < 12) return const [];

    final sentences = _sentences(words, from, to);
    final questions = <ClozeQuestion>[];
    final usedAnswers = <String>{};
    for (final sentence in sentences) {
      if (questions.length == 3) break;
      final question = _questionFor(sentence, words, from, to, usedAnswers);
      if (question == null) continue;
      usedAnswers.add(question.answer.toLowerCase());
      questions.add(question);
    }
    return questions;
  }

  static List<List<String>> _sentences(List<String> words, int from, int to) {
    final sentences = <List<String>>[];
    var current = <String>[];
    for (var i = from; i < to; i++) {
      final word = words[i];
      current.add(word);
      final last = word.isEmpty ? '' : word[word.length - 1];
      if (last == '.' || last == '!' || last == '?' || last == '…') {
        if (current.length >= 6) sentences.add(current);
        current = [];
      }
    }
    return sentences;
  }

  static ClozeQuestion? _questionFor(
    List<String> sentence,
    List<String> words,
    int from,
    int to,
    Set<String> usedAnswers,
  ) {
    String? answer;
    var answerAt = -1;
    for (var i = 0; i < sentence.length; i++) {
      final bare = _bare(sentence[i]);
      if (bare.length < 5 || _stop.contains(bare.toLowerCase())) continue;
      if (usedAnswers.contains(bare.toLowerCase())) continue;
      answer = bare;
      answerAt = i;
      break;
    }
    if (answer == null || answerAt < 0) return null;

    final distractors = <String>[];
    final seen = {answer.toLowerCase()};
    for (var i = from; i < to && distractors.length < 2; i++) {
      final bare = _bare(words[i]);
      final key = bare.toLowerCase();
      if (bare.length < 4 || seen.contains(key) || _stop.contains(key)) continue;
      seen.add(key);
      distractors.add(bare);
    }
    if (distractors.length < 2) return null;

    final choices = [answer, ...distractors];
    choices.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ClozeQuestion(
      before: sentence.sublist(0, answerAt).join(' '),
      after: sentence.sublist(answerAt + 1).join(' '),
      answer: answer,
      choices: choices,
    );
  }

  static String _bare(String word) {
    var end = word.length;
    while (end > 0 && '.,;:!?…"\'”’)]}'.contains(word[end - 1])) {
      end--;
    }
    var start = 0;
    while (start < end && '"\'“‘([{'.contains(word[start])) {
      start++;
    }
    return word.substring(start, end);
  }

}
