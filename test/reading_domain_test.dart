import 'package:apka/data/importers/txt_importer.dart';
import 'package:apka/domain/models/book_content.dart';
import 'package:apka/domain/reading/focal_point.dart';
import 'package:apka/domain/reading/tokenizer.dart';
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
}
