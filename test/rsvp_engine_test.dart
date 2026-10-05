import 'dart:async';

import 'package:apka/domain/models/book_content.dart';
import 'package:apka/domain/reading/tokenizer.dart';
import 'package:apka/domain/reading/word_timing.dart';
import 'package:apka/features/reader/engine/rsvp_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic clock + timer so scheduling can be asserted exactly.
class FakeScheduler {
  int now = 0;
  FakeTimer? pending;

  int clock() => now;

  Timer create(Duration delay, void Function() callback) {
    pending?.cancel();
    return pending = FakeTimer(now + delay.inMicroseconds, callback);
  }

  int get nextDelayMicros => pending!.dueAt - now;

  /// Fires the pending timer, optionally [lateBy] microseconds after its due time.
  void fire({int lateBy = 0}) {
    final timer = pending!;
    pending = null;
    now = timer.dueAt + lateBy;
    timer.run();
  }

  void advance(int micros) => now += micros;
}

class FakeTimer implements Timer {
  FakeTimer(this.dueAt, this._callback);

  final int dueAt;
  final void Function() _callback;
  bool _active = true;

  void run() {
    if (_active) {
      _active = false;
      _callback();
    }
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

BookContent _content(List<List<String>> chapters) => Tokenizer.tokenize([
      for (var i = 0; i < chapters.length; i++) ParsedChapter(title: 'Chapter ${i + 1}', paragraphs: chapters[i]),
    ]);

RsvpEngine _engine(
  FakeScheduler s,
  BookContent content, {
  int wpm = 300,
  bool smooth = false,
  WordTimingConfig timing = WordTimingConfig.standard,
  bool pauseAtChapterEnd = false,
}) =>
    RsvpEngine(
      content: content,
      wpm: wpm,
      timing: timing,
      smoothSpeedChanges: smooth,
      pauseAtChapterEnd: pauseAtChapterEnd,
      clock: s.clock,
      timerFactory: s.create,
    );

void main() {
  group('RsvpEngine timing', () {
    test('shows each word for exactly 60000 / WPM ms with standard timing', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        ['one two three four five six'],
      ]));
      engine.play();
      for (var i = 0; i < 4; i++) {
        expect(s.nextDelayMicros, 200000, reason: 'word $i at 300 WPM');
        s.fire();
      }
      expect(engine.position.value, 4);
    });

    test('compensates for late timers so average speed stays exact', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        ['a b c d e f g h'],
      ]));
      engine.play();
      s.fire(lateBy: 30000);
      expect(s.nextDelayMicros, 170000);
      s.fire();
      expect(s.now, 400000, reason: 'two words at 200 ms each despite the late tick');
      expect(engine.position.value, 2);
    });

    test('re-anchors after a long stall instead of flashing words', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        ['a b c d e f g h'],
      ]));
      engine.play();
      s.fire(lateBy: 5000000);
      expect(s.nextDelayMicros, greaterThanOrEqualTo(100000));
      expect(engine.position.value, 1);
    });

    test('applies punctuation and paragraph pauses', () {
      final s = FakeScheduler();
      final engine = _engine(
        s,
        _content([
          ['Hello, world.', 'Next'],
        ]),
        timing: const WordTimingConfig(longWordAdjustment: false),
      );
      engine.play();
      expect(s.nextDelayMicros, 250000, reason: 'comma = 1.25×');
      s.fire();
      expect(s.nextDelayMicros, 400000, reason: 'paragraph end = 2× (beats sentence 1.5×)');
    });

    test('ramps smoothly towards a new speed', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        [List.generate(60, (i) => 'w$i').join(' ')],
      ]), smooth: true);
      engine.play();
      for (var i = 0; i < 8; i++) {
        s.fire();
      }
      final before = s.nextDelayMicros;
      engine.setWpm(600);
      s.fire();
      final first = s.nextDelayMicros;
      expect(first, lessThan(before));
      expect(first, greaterThan(100000), reason: 'not an instant jump to 600 WPM');
      for (var i = 0; i < 40; i++) {
        s.fire();
      }
      expect(s.nextDelayMicros, closeTo(100000, 1000));
    });
  });

  group('RsvpEngine state', () {
    test('pause keeps position and only counts active time', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        ['a b c d e f'],
      ]));
      engine.play();
      s.fire();
      s.advance(50000);
      engine.pause();
      s.advance(10 * 1000000);
      expect(engine.position.value, 1);
      expect(engine.activeDuration.inMilliseconds, 250);
      engine.play();
      expect(engine.isPlaying, isTrue);
      expect(engine.position.value, 1);
    });

    test('skip clamps to book bounds', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        ['a b c'],
      ]));
      engine.skip(-10);
      expect(engine.position.value, 0);
      engine.skip(10);
      expect(engine.position.value, 2);
    });

    test('finishes at the last word and does not restart by itself', () {
      final s = FakeScheduler();
      var finished = 0;
      final engine = _engine(s, _content([
        ['a b'],
      ]))
        ..onFinished = () => finished++;
      engine.play();
      s.fire();
      s.fire();
      expect(finished, 1);
      expect(engine.isPlaying, isFalse);
      expect(engine.isFinished, isTrue);
      engine.play();
      expect(engine.isPlaying, isFalse);
    });

    test('pauses at chapter boundaries when asked', () {
      final s = FakeScheduler();
      int? chapter;
      final engine = _engine(
        s,
        _content([
          ['a b'],
          ['c d'],
        ]),
        pauseAtChapterEnd: true,
      )..onChapterEnd = (i) => chapter = i;
      engine.play();
      s.fire();
      s.fire();
      expect(chapter, 1);
      expect(engine.position.value, 2);
      expect(engine.isPlaying, isFalse);
    });

    test('average WPM is weighted by time at each speed', () {
      final s = FakeScheduler();
      final engine = _engine(s, _content([
        [List.generate(100, (i) => 'w$i').join(' ')],
      ]), wpm: 200);
      engine.play();
      s.advance(1000000);
      engine.setWpm(400);
      s.advance(1000000);
      engine.pause();
      expect(engine.averageWpm, 300);
    });
  });
}
