import 'package:apka/data/importers/txt_importer.dart';
import 'package:apka/data/importers/web_article.dart';
import 'package:apka/domain/models/book_content.dart';
import 'package:apka/domain/reading/comprehension_quiz.dart';
import 'package:apka/domain/reading/focal_point.dart';
import 'package:apka/domain/reading/reading_pace.dart';
import 'package:apka/domain/reading/tokenizer.dart';
import 'package:apka/domain/reading/training_pace.dart';
import 'package:apka/domain/reading/voice_pace.dart';
import 'package:apka/domain/reading/wpm_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tokenizer', () {
    test('flags punctuation, sentence ends and abbreviations', () {
      expect(Tokenizer.flagsFor('word,'), WordFlags.clauseEnd);
      expect(Tokenizer.flagsFor('end.'), WordFlags.sentenceEnd);
      expect(Tokenizer.flagsFor('really?”'), WordFlags.sentenceEnd);
      expect(Tokenizer.flagsFor('Mr.'), 0);
      expect(Tokenizer.flagsFor('plain'), 0);
    });

    test('splits glued dashes and marks paragraphs and chapters', () {
      final content = Tokenizer.tokenize(const [
        ParsedChapter(title: 'One', paragraphs: ['mind—and body', 'Second paragraph.']),
        ParsedChapter(title: 'Empty', paragraphs: ['   ']),
        ParsedChapter(title: 'Two', paragraphs: ['Last']),
      ]);
      expect(content.words, ['mind—', 'and', 'body', 'Second', 'paragraph.', 'Last']);
      expect(content.flags[2] & WordFlags.paragraphEnd, isNonZero);
      expect(content.flags[0] & WordFlags.chapterStart, isNonZero);
      expect(content.chapters.map((c) => c.title), ['One', 'Two']);
      expect(content.chapterIndexAt(4), 0);
      expect(content.chapterIndexAt(5), 1);
      expect(content.sentenceStart(4), 3);
      expect(content.sentenceEnd(4), 5);
      expect(content.sentenceText(4), 'Second paragraph.');
    });
  });

  group('FocalPoint', () {
    test('uses the optimal recognition point by word length', () {
      expect(FocalPoint.indexFor('a'), 0);
      expect(FocalPoint.indexFor('word'), 1);
      expect(FocalPoint.indexFor('reading'), 2);
      expect(FocalPoint.indexFor('comprehension'), 3);
      expect(FocalPoint.indexFor('internationalisation'), 4);
    });
  });

  group('WpmScale', () {
    test('uses 10 / 25 / 50 steps across the range', () {
      expect(WpmScale.step(250, 1), 260);
      expect(WpmScale.step(300, 1), 325);
      expect(WpmScale.step(600, 1), 650);
      expect(WpmScale.step(325, -1), 300);
      expect(WpmScale.step(1200, 1), 1200);
      expect(WpmScale.step(50, -1), 50);
      expect(WpmScale.snap(313), 325);
    });
  });

  group('TxtImporter', () {
    test('detects chapter headings without mistaking prose for them', () {
      final book = TxtImporter.parseText(
        'Chapter 1\n\nIt was a bright cold day.\n\nPart of me wanted to stay.\n\n'
        'CHAPTER II\n\nThe clocks were striking thirteen.',
      );
      expect(book.map((c) => c.title), ['Chapter 1', 'CHAPTER II']);
      expect(book.first.paragraphs, hasLength(2));
    });
  });

  group('VoicePace', () {
    test('speaks a chunk only while it stays up long enough', () {
      expect(VoicePace.canSpeak(300000), isTrue);
      expect(VoicePace.canSpeak(100000), isFalse);
      expect(VoicePace.phrase(['Quiet', 'morning', 'light'], 0, 1), 'Quiet');
      expect(VoicePace.phrase(['Quiet', 'morning', 'light'], 0, 3), 'Quiet morning light');
      expect(VoicePace.rateFor(160), 1);
      expect(VoicePace.rateFor(800), 1.65);
    });
  });

  group('TrainingPace', () {
    test('steps up after an easy session and down after several retraces', () {
      expect(TrainingPace.fromSession(current: 250, wordsRead: 40, retraces: 0), 250);
      expect(TrainingPace.fromSession(current: 250, wordsRead: 120, retraces: 0), 260);
      expect(TrainingPace.fromSession(current: 250, wordsRead: 120, retraces: 3), 240);
      expect(TrainingPace.fromQuiz(current: 250, correct: 3, asked: 3), 260);
      expect(TrainingPace.fromQuiz(current: 250, correct: 0, asked: 3), 240);
    });
  });

  group('ReadingPace', () {
    test('finishes today when a day of reading covers the rest', () {
      expect(ReadingPace.daysRemaining(wordsRemaining: 200, wpm: 250, minutesPerDay: 10), 0);
      final later = ReadingPace.finishOn(
        wordsRemaining: 250 * 10 * 3,
        wpm: 250,
        minutesPerDay: 10,
        from: DateTime(2026, 10, 6, 15),
      );
      expect(later, DateTime(2026, 10, 8));
    });
  });

  group('ComprehensionQuiz', () {
    test('builds a cloze question from a sentence in the passage', () {
      final words = 'Quiet mornings reward patient readers with clearer thoughts about every single page.'.split(' ');
      final questions = ComprehensionQuiz.build(words, 0, words.length);
      expect(questions, isNotEmpty);
      expect(questions.first.choices, contains(questions.first.answer));
    });
  });

  group('WebArticle', () {
    test('strips tags and keeps the title', () {
      final article = WebArticle.extract('<html><head><title>Morning note</title></head><body><p>Hello&amp; welcome.</p><script>secret()</script></body></html>');
      expect(article.title, 'Morning note');
      expect(article.text, contains('Hello& welcome.'));
      expect(article.text, isNot(contains('secret')));
    });
  });
}
