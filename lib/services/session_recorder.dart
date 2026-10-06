import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers.dart';
import '../core/utils/formatters.dart';
import '../data/providers.dart';
import '../domain/models/achievement.dart';
import '../domain/models/book.dart';
import '../domain/models/reading_session.dart';
import '../domain/reading/comprehension_quiz.dart';
import '../domain/reading/training_pace.dart';
import '../domain/stats/reading_stats.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/statistics/application/stats_providers.dart';
import 'analytics_service.dart';
import 'reminder_scheduler.dart';

final sessionRecorderProvider = Provider<SessionRecorder>((ref) => SessionRecorder(ref));

/// Everything shown on the "Nice session" screen.
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.book,
    required this.progressBefore,
    required this.progressAfter,
    required this.todaySecondsBefore,
    required this.todaySecondsAfter,
    required this.goalMinutes,
    required this.streakBefore,
    required this.streakAfter,
    required this.newAchievements,
    required this.bookCompleted,
    this.questions = const [],
    this.trainedToWpm,
  });

  final ReadingSession session;
  final Book book;
  final double progressBefore;
  final double progressAfter;
  final int todaySecondsBefore;
  final int todaySecondsAfter;
  final int goalMinutes;
  final int streakBefore;
  final int streakAfter;
  final List<AchievementDefinition> newAchievements;
  final bool bookCompleted;
  final List<ClozeQuestion> questions;

  /// The saved speed after training adjusted it, when it moved.
  final int? trainedToWpm;

  SessionSummary copyWith({List<ClozeQuestion>? questions, int? trainedToWpm}) => SessionSummary(
        session: session,
        book: book,
        progressBefore: progressBefore,
        progressAfter: progressAfter,
        todaySecondsBefore: todaySecondsBefore,
        todaySecondsAfter: todaySecondsAfter,
        goalMinutes: goalMinutes,
        streakBefore: streakBefore,
        streakAfter: streakAfter,
        newAchievements: newAchievements,
        bookCompleted: bookCompleted,
        questions: questions ?? this.questions,
        trainedToWpm: trainedToWpm ?? this.trainedToWpm,
      );

  bool get goalReachedThisSession =>
      todaySecondsBefore < goalMinutes * 60 && todaySecondsAfter >= goalMinutes * 60;
}

/// Turns a finished reading session into durable records: session log, book
/// progress, profile aggregates, achievements, reminders and analytics.
class SessionRecorder {
  SessionRecorder(this._ref);

  final Ref _ref;

  ReadingStats _computeStats() => StatsCalculator.compute(
        sessions: _ref.read(sessionRepositoryProvider).all,
        books: _ref.read(bookRepositoryProvider).all,
        currentGoalMinutes: _ref.read(goalMinutesProvider),
      );

  /// Returns null when the session was too short to count; progress is still
  /// saved in that case.
  Future<SessionSummary?> record(
    SessionDraft draft, {
    required int chapter,
    required bool finishedBook,
  }) async {
    final books = _ref.read(bookRepositoryProvider);
    final sessions = _ref.read(sessionRepositoryProvider);
    final profile = _ref.read(profileRepositoryProvider);
    final analytics = _ref.read(analyticsProvider);
    final minSeconds = _ref.read(settingsControllerProvider).minSessionSeconds;

    final seconds = (draft.activeMicros / Duration.microsecondsPerSecond).round();
    final bookBefore = books.byId(draft.bookId);
    if (bookBefore == null) {
      await sessions.clearDraft();
      return null;
    }

    if (seconds < minSeconds || draft.wordsRead == 0) {
      await books.saveProgress(draft.bookId, wordIndex: draft.currentPosition, chapter: chapter);
      if (finishedBook) await books.setCompleted(draft.bookId, true);
      await books.pushProgress(draft.bookId);
      await sessions.clearDraft();
      return null;
    }

    final statsBefore = _computeStats();
    final goalMinutes = _ref.read(goalMinutesProvider);
    final clampedSeconds = seconds.clamp(1, SessionConstants.maxSessionSeconds);
    final session = ReadingSession(
      id: draft.id,
      userId: _ref.read(userScopeProvider).uid,
      bookId: draft.bookId,
      bookTitle: draft.bookTitle,
      startTime: draft.startTime,
      endTime: draft.lastUpdate,
      durationSeconds: clampedSeconds,
      wordsRead: draft.wordsRead,
      startingWpm: draft.startingWpm,
      endingWpm: draft.currentWpm,
      averageWpm: draft.averageWpm.clamp(ReaderConstants.minWpm, ReaderConstants.maxWpm),
      effectiveWpm: (draft.wordsRead / (clampedSeconds / 60)).round(),
      startingPosition: draft.startingPosition,
      endingPosition: draft.currentPosition,
      startPercentage: draft.startPercentage,
      completionPercentage: finishedBook ? 1 : draft.currentPercentage,
      localDate: DayKey.of(draft.startTime),
      goalMinutes: goalMinutes,
      bookCompleted: finishedBook && !bookBefore.completed,
    );

    await sessions.add(session);
    final bookAfter = await books.recordSession(
          draft.bookId,
          wordsRead: draft.wordsRead,
          seconds: clampedSeconds,
          endIndex: draft.currentPosition,
          chapter: chapter,
          finished: finishedBook,
        ) ??
        bookBefore;

    final statsAfter = _computeStats();
    await profile.applyStats(statsAfter);
    await profile.setCurrentWpm(draft.currentWpm);
    int? trainedTo;
    final settings = _ref.read(readerSettingsProvider);
    if (settings.trainingMode) {
      final next = TrainingPace.fromSession(
        current: settings.defaultWpm,
        wordsRead: draft.wordsRead,
        retraces: draft.retraces,
      );
      if (next != settings.defaultWpm) {
        await _ref.read(settingsControllerProvider.notifier).updateReader((r) => r.copyWith(defaultWpm: next));
        trainedTo = next;
      }
    }
    final fresh = await _ref.read(achievementRepositoryProvider).evaluate(statsAfter);
    await sessions.clearDraft();

    await analytics.log(AnalyticsEvents.readingSessionCompleted, {
      'duration_seconds': clampedSeconds,
      'words_read': draft.wordsRead,
      'average_wpm': session.averageWpm,
    });
    if (session.bookCompleted) {
      await analytics.log(AnalyticsEvents.bookCompleted, {'format': bookAfter.format.name});
    }
    for (final achievement in fresh) {
      await analytics.log(AnalyticsEvents.achievementUnlocked, {'achievement_id': achievement.id});
    }
    await _ref.read(reminderSchedulerProvider).reschedule();

    return SessionSummary(
      session: session,
      book: bookAfter,
      progressBefore: draft.startPercentage,
      progressAfter: bookAfter.progress,
      todaySecondsBefore: statsBefore.days[session.localDate]?.seconds ?? 0,
      todaySecondsAfter: statsAfter.days[session.localDate]?.seconds ?? 0,
      goalMinutes: goalMinutes,
      streakBefore: statsBefore.streak.current,
      streakAfter: statsAfter.streak.current,
      newAchievements: fresh,
      bookCompleted: session.bookCompleted,
      trainedToWpm: trainedTo,
    );
  }

  /// Records a session interrupted by the app being killed.
  Future<void> recoverDraft() async {
    final sessions = _ref.read(sessionRepositoryProvider);
    final draft = sessions.draft;
    if (draft == null) return;
    final book = _ref.read(bookRepositoryProvider).byId(draft.bookId);
    await record(draft, chapter: book?.currentChapter ?? 0, finishedBook: false);
  }
}
