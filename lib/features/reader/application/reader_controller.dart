import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/reader_settings.dart';
import '../../../domain/models/reading_session.dart';
import '../../../domain/reading/word_timing.dart';
import '../../../services/analytics_service.dart';
import '../../../services/session_recorder.dart';
import '../../settings/application/settings_controller.dart';
import '../engine/rsvp_engine.dart';

typedef ReaderArgs = ({String bookId, int? startIndex});

enum ReaderStatus { loading, ready, error }

class ReaderState {
  const ReaderState._({
    required this.status,
    this.book,
    this.engine,
    this.error,
    this.chapterBreak,
    this.finished = false,
  });

  const ReaderState.loading() : this._(status: ReaderStatus.loading);

  const ReaderState.error(Object error) : this._(status: ReaderStatus.error, error: error);

  const ReaderState.ready(Book book, RsvpEngine engine)
      : this._(status: ReaderStatus.ready, book: book, engine: engine);

  final ReaderStatus status;
  final Book? book;
  final RsvpEngine? engine;
  final Object? error;

  /// Index of the chapter the reader paused in front of (when auto-start
  /// next chapter is off).
  final int? chapterBreak;
  final bool finished;

  ReaderState copyWith({int? chapterBreak, bool clearChapterBreak = false, bool? finished}) => ReaderState._(
        status: status,
        book: book,
        engine: engine,
        error: error,
        chapterBreak: clearChapterBreak ? null : (chapterBreak ?? this.chapterBreak),
        finished: finished ?? this.finished,
      );
}

final readerControllerProvider =
    NotifierProvider.autoDispose.family<ReaderController, ReaderState, ReaderArgs>(ReaderController.new);

class _SessionStart {
  _SessionStart({
    required this.id,
    required this.startTime,
    required this.startingWpm,
    required this.startingPosition,
    required this.startPercentage,
  });

  final String id;
  final DateTime startTime;
  final int startingWpm;
  final int startingPosition;
  final double startPercentage;
}

/// Owns the [RsvpEngine] for one reading screen and connects it to the rest
/// of the app: settings, progress persistence, session logging, wakelock and
/// app lifecycle. Living outside the widget tree means rotation and rebuilds
/// never interrupt playback or lose position.
class ReaderController extends Notifier<ReaderState> {
  ReaderController(this.args);

  final ReaderArgs args;

  static const Duration _wpmPersistDebounce = Duration(milliseconds: 800);

  RsvpEngine? _engine;
  BookRepository? _books;
  SessionRepository? _sessions;
  Timer? _persistTimer;
  Timer? _wpmDebounce;
  _SessionStart? _session;
  int? _wpmBeforeChange;
  bool _finishing = false;

  RsvpEngine? get engine => _engine;

  @override
  ReaderState build() {
    ref.onDispose(_dispose);
    ref.listen<ReaderSettings>(readerSettingsProvider, (_, next) => _applySettings(next));
    Future.microtask(_load);
    return const ReaderState.loading();
  }

  Future<void> _load() async {
    try {
      final books = ref.read(bookRepositoryProvider);
      _books = books;
      _sessions = ref.read(sessionRepositoryProvider);
      final book = books.byId(args.bookId);
      if (book == null) throw const AppFailure("We couldn't find this book in your library.");
      final content = await books.loadContent(book.id);
      if (!ref.mounted) return;

      final settings = ref.read(readerSettingsProvider);
      var start = args.startIndex ?? book.currentWordIndex;
      if (args.startIndex == null && book.completed) {
        start = 0;
        await books.restart(book.id);
      }
      final engine = RsvpEngine(
        content: content,
        wpm: settings.defaultWpm,
        startIndex: start,
        timing: WordTimingConfig.fromSettings(settings),
        smoothSpeedChanges: settings.smoothSpeedChanges,
        pauseAtChapterEnd: !settings.autoStartNextChapter,
      )
        ..onFinished = _onFinished
        ..onChapterEnd = _onChapterEnd;
      engine.playing.addListener(_onPlayingChanged);
      _engine = engine;

      final opened = await books.markOpened(book.id) ?? book;
      if (!book.isStarted) {
        unawaited(ref.read(analyticsProvider).log(AnalyticsEvents.bookStarted, {'format': book.format.name}));
      }
      if (ref.mounted) state = ReaderState.ready(opened, engine);
    } on Object catch (e, s) {
      ref.read(crashReporterProvider).recordNonFatal(e, s, reason: 'reader load');
      if (ref.mounted) state = ReaderState.error(e);
    }
  }

  // --- commands ------------------------------------------------------------

  void togglePlay() {
    final engine = _engine;
    if (engine == null) return;
    if (state.chapterBreak != null) state = state.copyWith(clearChapterBreak: true);
    if (engine.isFinished) return;
    engine.toggle();
  }

  void pause() => _engine?.pause();

  void skip(int words) => _engine?.skip(words);

  void seek(int index) {
    _engine?.seek(index);
    if (state.chapterBreak != null || state.finished) {
      state = state.copyWith(clearChapterBreak: true, finished: false);
    }
  }

  void seekToChapter(int chapterIndex) {
    final engine = _engine;
    if (engine == null || engine.content.chapters.isEmpty) return;
    final chapters = engine.content.chapters;
    seek(chapters[chapterIndex.clamp(0, chapters.length - 1)].startIndex);
  }

  void seekToFraction(double fraction) {
    final engine = _engine;
    if (engine == null) return;
    seek((fraction.clamp(0.0, 1.0) * (engine.content.length - 1)).round());
  }

  void continueAfterChapterBreak() {
    state = state.copyWith(clearChapterBreak: true);
    _engine?.play();
  }

  void setWpm(int wpm) {
    final engine = _engine;
    if (engine == null) return;
    _wpmBeforeChange ??= engine.wpm.value;
    engine.setWpm(wpm);
    _wpmDebounce?.cancel();
    _wpmDebounce = Timer(_wpmPersistDebounce, _persistWpm);
  }

  void _persistWpm() {
    final engine = _engine;
    final from = _wpmBeforeChange;
    _wpmBeforeChange = null;
    if (engine == null || from == null || from == engine.wpm.value) return;
    final to = engine.wpm.value;
    ref.read(settingsControllerProvider.notifier).updateReader((r) => r.copyWith(defaultWpm: to));
    unawaited(ref.read(analyticsProvider).log(AnalyticsEvents.wpmChanged, {'from': from, 'to': to}));
  }

  void handleLifecycle(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) return;
    _engine?.pause();
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      unawaited(ref.read(bookRepositoryProvider).pushProgress(args.bookId));
    }
  }

  /// Ends the session. Returns a summary when the session was long enough to
  /// count; progress is always saved.
  Future<SessionSummary?> finish() async {
    if (_finishing) return null;
    _finishing = true;
    final engine = _engine;
    if (engine == null) return null;
    engine.pause();
    _wpmDebounce?.cancel();
    _persistWpm();

    final draft = _draft();
    final chapter = engine.content.chapterIndexAt(engine.position.value);
    try {
      if (draft == null) {
        await _saveProgress();
        await ref.read(bookRepositoryProvider).pushProgress(args.bookId);
        return null;
      }
      return await ref.read(sessionRecorderProvider).record(
            draft,
            chapter: chapter,
            finishedBook: engine.isFinished,
          );
    } on Object catch (e, s) {
      ref.read(crashReporterProvider).recordNonFatal(e, s, reason: 'finish session');
      return null;
    } finally {
      _session = null;
      _finishing = false;
    }
  }

  // --- engine events ---------------------------------------------------------

  void _onPlayingChanged() {
    final engine = _engine;
    if (engine == null) return;
    final settings = ref.read(readerSettingsProvider);
    if (engine.isPlaying) {
      _startSessionIfNeeded(engine);
      _persistTimer?.cancel();
      _persistTimer = Timer.periodic(ReaderConstants.progressPersistInterval, (_) => _saveProgress());
      if (settings.keepScreenAwake) _setWakelock(true);
    } else {
      _persistTimer?.cancel();
      _persistTimer = null;
      _setWakelock(false);
      unawaited(_saveProgress());
    }
  }

  void _startSessionIfNeeded(RsvpEngine engine) {
    if (_session != null) return;
    final book = state.book;
    final total = engine.content.length;
    _session = _SessionStart(
      id: const Uuid().v4(),
      startTime: DateTime.now(),
      startingWpm: engine.wpm.value,
      startingPosition: engine.position.value,
      startPercentage: book?.completed == true || total <= 1 ? 0 : engine.position.value / (total - 1),
    );
    unawaited(ref.read(analyticsProvider).log(AnalyticsEvents.readingSessionStarted, {'wpm': engine.wpm.value}));
  }

  void _onChapterEnd(int chapterIndex) {
    if (ref.mounted) state = state.copyWith(chapterBreak: chapterIndex);
  }

  void _onFinished() {
    if (ref.mounted) state = state.copyWith(finished: true);
  }

  void _applySettings(ReaderSettings settings) {
    final engine = _engine;
    if (engine == null) return;
    engine
      ..updateTiming(WordTimingConfig.fromSettings(settings))
      ..smoothSpeedChanges = settings.smoothSpeedChanges
      ..pauseAtChapterEnd = !settings.autoStartNextChapter;
    if (engine.isPlaying) _setWakelock(settings.keepScreenAwake);
  }

  // --- persistence -----------------------------------------------------------

  SessionDraft? _draft() {
    final engine = _engine;
    final session = _session;
    if (engine == null || session == null) return null;
    final total = engine.content.length;
    return SessionDraft(
      id: session.id,
      bookId: args.bookId,
      bookTitle: state.book?.title ?? '',
      startTime: session.startTime,
      lastUpdate: DateTime.now(),
      activeMicros: engine.activeMicros,
      wordsRead: engine.wordsAdvanced,
      startingWpm: session.startingWpm,
      currentWpm: engine.wpm.value,
      averageWpm: engine.averageWpm,
      startingPosition: session.startingPosition,
      currentPosition: engine.position.value,
      startPercentage: session.startPercentage,
      currentPercentage: total <= 1 ? 0 : engine.position.value / (total - 1),
    );
  }

  /// Uses repositories captured at load time so it is also safe to call while
  /// the provider is being disposed.
  Future<void> _saveProgress() async {
    final engine = _engine;
    final books = _books;
    if (engine == null || books == null) return;
    try {
      await books.saveProgress(
        args.bookId,
        wordIndex: engine.position.value,
        chapter: engine.content.chapterIndexAt(engine.position.value),
      );
      final draft = _draft();
      if (draft != null) await _sessions?.saveDraft(draft);
    } on Object catch (e) {
      debugPrint('Reader: failed to save progress: $e');
    }
  }

  void _setWakelock(bool enabled) {
    unawaited((enabled ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((Object _) {}));
  }

  void _dispose() {
    _persistTimer?.cancel();
    _wpmDebounce?.cancel();
    _setWakelock(false);
    final engine = _engine;
    if (engine != null) {
      engine.playing.removeListener(_onPlayingChanged);
      engine.pause();
      // Final save before the engine goes away; the draft lets an unfinished
      // session be recorded on next launch.
      final pending = _saveProgress();
      unawaited(pending.whenComplete(engine.dispose));
    }
  }
}
