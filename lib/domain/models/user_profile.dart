import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';

enum AuthProviderKind { password, google, local }

/// The authenticated identity, independent of any auth backend.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.provider,
    this.displayName,
    this.photoUrl,
    this.lastSignInAt,
  });

  final String uid;
  final String email;
  final AuthProviderKind provider;
  final String? displayName;
  final String? photoUrl;
  final DateTime? lastSignInAt;

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.avatar,
    this.readingGoalMinutes = GoalConstants.defaultDailyMinutes,
    this.currentWpm = ReaderConstants.defaultWpm,
    this.totalWordsRead = 0,
    this.totalReadingTime = 0,
    this.booksCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastReadingDate,
    this.syncPending = true,
  });

  final String uid;
  final String name;
  final String email;

  /// Remote URL or local file path of the avatar image.
  final String? avatar;
  final DateTime createdAt;
  final int readingGoalMinutes;
  final int currentWpm;
  final int totalWordsRead;

  /// Seconds.
  final int totalReadingTime;
  final int booksCompleted;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastReadingDate;
  final bool syncPending;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'reader';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? avatar,
    int? readingGoalMinutes,
    int? currentWpm,
    int? totalWordsRead,
    int? totalReadingTime,
    int? booksCompleted,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastReadingDate,
    bool? syncPending,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        createdAt: createdAt,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        readingGoalMinutes: readingGoalMinutes ?? this.readingGoalMinutes,
        currentWpm: currentWpm ?? this.currentWpm,
        totalWordsRead: totalWordsRead ?? this.totalWordsRead,
        totalReadingTime: totalReadingTime ?? this.totalReadingTime,
        booksCompleted: booksCompleted ?? this.booksCompleted,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastReadingDate: lastReadingDate ?? this.lastReadingDate,
        syncPending: syncPending ?? this.syncPending,
      );

  /// Fields the client is allowed to write. Aggregates (totals, streaks) are
  /// computed server-side from sessions and are not accepted from clients.
  JsonMap toEditableJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'avatar': avatar,
        'createdAt': millis(createdAt),
        'readingGoalMinutes': readingGoalMinutes,
        'currentWpm': currentWpm,
      };

  JsonMap toJson() => {
        ...toEditableJson(),
        'totalWordsRead': totalWordsRead,
        'totalReadingTime': totalReadingTime,
        'booksCompleted': booksCompleted,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastReadingDate': millis(lastReadingDate),
        'syncPending': syncPending,
      };

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        uid: json.str('uid'),
        name: json.str('name'),
        email: json.str('email'),
        avatar: json.strOrNull('avatar'),
        createdAt: json.date('createdAt') ?? DateTime.now(),
        readingGoalMinutes: json.integer('readingGoalMinutes', GoalConstants.defaultDailyMinutes),
        currentWpm: json.integer('currentWpm', ReaderConstants.defaultWpm),
        totalWordsRead: json.integer('totalWordsRead'),
        totalReadingTime: json.integer('totalReadingTime'),
        booksCompleted: json.integer('booksCompleted'),
        currentStreak: json.integer('currentStreak'),
        longestStreak: json.integer('longestStreak'),
        lastReadingDate: json.date('lastReadingDate'),
        syncPending: json.boolean('syncPending', false),
      );
}
