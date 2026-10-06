import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/book_content.dart';
import '../../../domain/reading/word_timing.dart';

typedef MicrosClock = int Function();
typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

/// Drives RSVP playback with deadline-based scheduling.
///
/// Every word gets an absolute deadline on a monotonic clock. Each tick
/// schedules the next timer relative to that deadline rather than "now", so
/// timer latency never accumulates: average speed stays exact even when
/// individual frames are late. If the engine falls far behind (jank, the OS
/// throttling timers), it re-anchors instead of flashing words in a burst.
///
/// The engine exposes [ValueListenable]s so the UI can repaint only the word
/// without rebuilding the widget tree.
class RsvpEngine {
  RsvpEngine({
    required BookContent content,
    required int wpm,
    int startIndex = 0,
    WordTimingConfig timing = const WordTimingConfig(),
    this.smoothSpeedChanges = true,
    this.pauseAtChapterEnd = false,
    int chunkSize = 1,
    MicrosClock? clock,
    TimerFactory? timerFactory,
  })  : _content = content,
        _timing = timing,
        _clock = clock ?? _defaultClock(),
        _timerFactory = timerFactory ?? Timer.new,
        position = ValueNotifier<int>(
          content.isEmpty ? 0 : startIndex.clamp(0, content.length - 1),
        ),
        playing = ValueNotifier<bool>(false),
        wpm = ValueNotifier<int>(_clampWpm(wpm)),
        _effectiveWpm = _clampWpm(wpm).toDouble(),
        _chunkSize = chunkSize.clamp(1, 3);

  static MicrosClock _defaultClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMicroseconds;
  }

  static int _clampWpm(int value) =>
      value.clamp(ReaderConstants.minWpm, ReaderConstants.maxWpm);

  final BookContent _content;
  final MicrosClock _clock;
  final TimerFactory _timerFactory;
  WordTimingConfig _timing;

  bool smoothSpeedChanges;
  bool pauseAtChapterEnd;
  int _chunkSize;

  /// Index of the word currently displayed.
  final ValueNotifier<int> position;
  final ValueNotifier<bool> playing;

  /// The speed the reader selected. While ramping, the engine may briefly run
  /// at a speed between the previous and this value.
  final ValueNotifier<int> wpm;

  /// Called when the last word has been shown.
  VoidCallback? onFinished;

  /// Called after pausing at the start of a new chapter.
  void Function(int chapterIndex)? onChapterEnd;

  Timer? _timer;
  int _deadline = 0;
  double _effectiveWpm;
  int _warmupRemaining = 0;
  bool _disposed = false;
  bool _finished = false;

  int _playStartedAt = 0;
  int _accumulatedActive = 0;
  int _wordsAdvanced = 0;
  int _lastSample = 0;
  double _wpmIntegral = 0;
  int _sampledMicros = 0;
  int _retraces = 0;

  BookContent get content => _content;
  bool get isFinished => _finished;
  bool get isPlaying => playing.value;

  /// Active (playing) reading time in microseconds.
  int get activeMicros =>
      _accumulatedActive + (playing.value ? _clock() - _playStartedAt : 0);

  Duration get activeDuration => Duration(microseconds: activeMicros);

  /// Words that were fully displayed during playback.
  int get wordsAdvanced => _wordsAdvanced;

  /// Times the reader jumped backward: a skip, a seek, or a sentence replay.
  int get retraces => _retraces;

  int get chunkSize => _chunkSize;

  /// How long the chunk at [index] stays on screen, in microseconds.
  int displayMicrosAt(int index) {
    if (index < 0 || index >= _content.length) return 0;
    return _chunkDuration(index);
  }

  /// Time-weighted average of the selected speed while playing.
  int get averageWpm {
    if (_sampledMicros == 0) return wpm.value;
    return (_wpmIntegral / _sampledMicros).round();
  }

  int get wordsRemaining => math.max(0, _content.length - position.value - 1);

  void play() {
    if (_disposed || playing.value || _content.isEmpty) return;
    if (_finished) return;
    final now = _clock();
    _playStartedAt = now;
    _lastSample = now;
    _effectiveWpm = wpm.value.toDouble();
    _warmupRemaining = smoothSpeedChanges ? ReaderConstants.resumeWarmupWords : 0;
    playing.value = true;
    _deadline = now + _chunkDuration(position.value);
    _arm(now);
  }

  void pause() {
    if (!playing.value) return;
    _stop(_clock());
  }

  void toggle() => playing.value ? pause() : play();

  /// Jumps to [index]. Playback continues from the new position if playing.
  void seek(int index) {
    if (_disposed || _content.isEmpty) return;
    final target = index.clamp(0, _content.length - 1);
    if (target < position.value) _retraces++;
    _finished = false;
    position.value = target;
    if (playing.value) {
      final now = _clock();
      _warmupRemaining = smoothSpeedChanges ? ReaderConstants.resumeWarmupWords ~/ 2 : 0;
      _deadline = now + _chunkDuration(target);
      _arm(now);
    }
  }

  void skip(int delta) => seek(position.value + delta);

  /// Jumps to the first word of the sentence on screen. If that word is
  /// already showing, jumps to the sentence before it.
  void replaySentence() {
    if (_content.isEmpty) return;
    final here = position.value;
    final start = _content.sentenceStart(here);
    if (start < here) {
      seek(start);
      return;
    }
    if (start > 0) seek(_content.sentenceStart(start - 1));
  }

  void setChunkSize(int value) {
    final next = value.clamp(1, 3);
    if (next == _chunkSize) return;
    _chunkSize = next;
  }

  void setWpm(int value) {
    final clamped = _clampWpm(value);
    if (clamped == wpm.value) return;
    if (playing.value) _sample(_clock());
    wpm.value = clamped;
    if (!playing.value || !smoothSpeedChanges) _effectiveWpm = clamped.toDouble();
  }

  void updateTiming(WordTimingConfig timing) => _timing = timing;

  void dispose() {
    if (_disposed) return;
    if (playing.value) _stop(_clock());
    _disposed = true;
    _timer?.cancel();
    position.dispose();
    playing.dispose();
    wpm.dispose();
  }

  // --- internals -----------------------------------------------------------

  void _arm(int now) {
    _timer?.cancel();
    final delay = math.max(0, _deadline - now);
    _timer = _timerFactory(Duration(microseconds: delay), _onTick);
  }

  void _onTick() {
    if (_disposed || !playing.value) return;
    final now = _clock();
    _sample(now);
    final shown = _shownCount(position.value);
    _wordsAdvanced += shown;

    final next = position.value + shown;
    if (next >= _content.length) {
      _finished = true;
      _stop(now);
      onFinished?.call();
      return;
    }

    if (pauseAtChapterEnd && _content.isChapterStart(next)) {
      position.value = next;
      _stop(now);
      onChapterEnd?.call(_content.chapterIndexAt(next));
      return;
    }

    position.value = next;
    if (_warmupRemaining > 0) _warmupRemaining--;
    _rampTowardsTarget();

    final duration = _chunkDuration(next);
    _deadline += duration;
    final earliest = now + (duration * ReaderConstants.minDisplayFraction).round();
    if (_deadline < earliest) _deadline = earliest;
    _arm(now);
  }

  void _stop(int now) {
    _timer?.cancel();
    _timer = null;
    _sample(now);
    _accumulatedActive += now - _playStartedAt;
    playing.value = false;
  }

  void _sample(int now) {
    final elapsed = now - _lastSample;
    if (elapsed > 0) {
      _wpmIntegral += _effectiveWpm * elapsed;
      _sampledMicros += elapsed;
    }
    _lastSample = now;
  }

  void _rampTowardsTarget() {
    final target = wpm.value.toDouble();
    if (!smoothSpeedChanges) {
      _effectiveWpm = target;
      return;
    }
    final gap = target - _effectiveWpm;
    _effectiveWpm = gap.abs() < 1 ? target : _effectiveWpm + gap * ReaderConstants.wpmRampFactor;
  }

  /// Words included in the chunk currently on screen.
  int _shownCount(int index) {
    final room = _content.length - index;
    if (room <= 0) return 1;
    final count = math.min(_chunkSize, room);
    if (pauseAtChapterEnd) {
      for (var i = 1; i < count; i++) {
        if (_content.isChapterStart(index + i)) return i;
      }
    }
    return count;
  }

  int _chunkDuration(int index) {
    final count = _shownCount(index);
    var total = 0;
    for (var i = 0; i < count; i++) {
      total += _durationOf(index + i);
    }
    return total;
  }

  int _durationOf(int index) {
    var micros = WordTiming.durationMicros(
      _content.words[index],
      _content.flags[index],
      _effectiveWpm,
      _timing,
    );
    if (_warmupRemaining > 0) {
      const start = ReaderConstants.resumeWarmupStartFactor;
      final progress = 1 - _warmupRemaining / ReaderConstants.resumeWarmupWords;
      final speedFactor = start + (1 - start) * progress;
      micros = (micros / speedFactor).round();
    }
    return micros;
  }
}
