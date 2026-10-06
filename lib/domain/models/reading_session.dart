import '../../core/utils/json.dart';

class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.wordsRead,
    required this.startingWpm,
    required this.endingWpm,
    required this.averageWpm,
    required this.effectiveWpm,
    required this.startingPosition,
    required this.endingPosition,
    required this.startPercentage,
    required this.completionPercentage,
    required this.localDate,
    required this.goalMinutes,
    this.bookCompleted = false,
    this.synced = false,
  });

  final String id;
  final String userId;
  final String bookId;
  final String bookTitle;
  final DateTime startTime;
  final DateTime endTime;

  /// Active reading time (paused time excluded).
  final int durationSeconds;
  final int wordsRead;
  final int startingWpm;
  final int endingWpm;

  /// Time-weighted average of the speed the reader had selected.
  final int averageWpm;

  /// Words actually displayed per minute, including natural pauses.
  final int effectiveWpm;
  final int startingPosition;
  final int endingPosition;
  final double startPercentage;
  final double completionPercentage;

  /// Local calendar day ("yyyy-MM-dd") the session counts towards.
  final String localDate;

  /// Daily goal in effect when the session was recorded.
  final int goalMinutes;
  final bool bookCompleted;
  final bool synced;

  Duration get duration => Duration(seconds: durationSeconds);

  ReadingSession markSynced() => ReadingSession(
        id: id,
        userId: userId,
        bookId: bookId,
        bookTitle: bookTitle,
        startTime: startTime,
        endTime: endTime,
        durationSeconds: durationSeconds,
        wordsRead: wordsRead,
        startingWpm: startingWpm,
        endingWpm: endingWpm,
        averageWpm: averageWpm,
        effectiveWpm: effectiveWpm,
        startingPosition: startingPosition,
        endingPosition: endingPosition,
        startPercentage: startPercentage,
        completionPercentage: completionPercentage,
        localDate: localDate,
        goalMinutes: goalMinutes,
        bookCompleted: bookCompleted,
        synced: true,
      );

  JsonMap toRemoteJson() => {
        'sessionId': id,
        'userId': userId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'startTime': millis(startTime),
        'endTime': millis(endTime),
        'duration': durationSeconds,
        'wordsRead': wordsRead,
        'startingWpm': startingWpm,
        'endingWpm': endingWpm,
        'averageWpm': averageWpm,
        'effectiveWpm': effectiveWpm,
        'startingPosition': startingPosition,
        'endingPosition': endingPosition,
        'startPercentage': startPercentage,
        'completionPercentage': completionPercentage,
        'localDate': localDate,
        'goalMinutes': goalMinutes,
        'bookCompleted': bookCompleted,
      };

  JsonMap toJson() => {...toRemoteJson(), 'synced': synced};

  factory ReadingSession.fromJson(JsonMap json) {
    final start = json.date('startTime') ?? DateTime.now();
    return ReadingSession(
      id: json.str('sessionId'),
      userId: json.str('userId'),
      bookId: json.str('bookId'),
      bookTitle: json.str('bookTitle'),
      startTime: start,
      endTime: json.date('endTime') ?? start,
      durationSeconds: json.integer('duration'),
      wordsRead: json.integer('wordsRead'),
      startingWpm: json.integer('startingWpm'),
      endingWpm: json.integer('endingWpm'),
      averageWpm: json.integer('averageWpm'),
      effectiveWpm: json.integer('effectiveWpm'),
      startingPosition: json.integer('startingPosition'),
      endingPosition: json.integer('endingPosition'),
      startPercentage: json.dbl('startPercentage'),
      completionPercentage: json.dbl('completionPercentage'),
      localDate: json.str('localDate'),
      goalMinutes: json.integer('goalMinutes', 20),
      bookCompleted: json.boolean('bookCompleted'),
      synced: json.boolean('synced'),
    );
  }
}

/// A session in progress, persisted periodically so that reading time is not
/// lost if the app is killed mid-session.
class SessionDraft {
  const SessionDraft({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.startTime,
    required this.lastUpdate,
    required this.activeMicros,
    required this.wordsRead,
    required this.startingWpm,
    required this.currentWpm,
    required this.averageWpm,
    required this.startingPosition,
    required this.currentPosition,
    required this.startPercentage,
    required this.currentPercentage,
    this.retraces = 0,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime startTime;
  final DateTime lastUpdate;
  final int activeMicros;
  final int wordsRead;
  final int startingWpm;
  final int currentWpm;
  final int averageWpm;
  final int startingPosition;
  final int currentPosition;
  final double startPercentage;
  final double currentPercentage;

  /// Backward jumps during the session. Used by training mode.
  final int retraces;

  JsonMap toJson() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'startTime': millis(startTime),
        'lastUpdate': millis(lastUpdate),
        'activeMicros': activeMicros,
        'wordsRead': wordsRead,
        'startingWpm': startingWpm,
        'currentWpm': currentWpm,
        'averageWpm': averageWpm,
        'startingPosition': startingPosition,
        'currentPosition': currentPosition,
        'startPercentage': startPercentage,
        'currentPercentage': currentPercentage,
        'retraces': retraces,
      };

  factory SessionDraft.fromJson(JsonMap json) {
    final start = json.date('startTime') ?? DateTime.now();
    return SessionDraft(
      id: json.str('id'),
      bookId: json.str('bookId'),
      bookTitle: json.str('bookTitle'),
      startTime: start,
      lastUpdate: json.date('lastUpdate') ?? start,
      activeMicros: json.integer('activeMicros'),
      wordsRead: json.integer('wordsRead'),
      startingWpm: json.integer('startingWpm'),
      currentWpm: json.integer('currentWpm'),
      averageWpm: json.integer('averageWpm'),
      startingPosition: json.integer('startingPosition'),
      currentPosition: json.integer('currentPosition'),
      startPercentage: json.dbl('startPercentage'),
      currentPercentage: json.dbl('currentPercentage'),
      retraces: json.integer('retraces'),
    );
  }
}
