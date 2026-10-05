import '../../core/utils/json.dart';

enum AchievementMetric { totalWords, sessions, highestWpm, booksCompleted, longestStreak, totalSeconds }

enum AchievementGlyph { spark, play, gauge, bolt, lightning, book, library, mountain, flame, crown, clock }

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.threshold,
    required this.glyph,
    required this.unit,
  });

  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int threshold;
  final AchievementGlyph glyph;

  /// Unit label for progress text, e.g. "words".
  final String unit;
}

class UnlockedAchievement {
  const UnlockedAchievement({required this.id, required this.unlockedAt, this.verified = false});

  final String id;
  final DateTime unlockedAt;

  /// True once confirmed by the server-side evaluator.
  final bool verified;

  JsonMap toJson() => {'id': id, 'unlockedAt': millis(unlockedAt), 'verified': verified};

  factory UnlockedAchievement.fromJson(JsonMap json) => UnlockedAchievement(
        id: json.str('id'),
        unlockedAt: json.date('unlockedAt') ?? DateTime.now(),
        verified: json.boolean('verified'),
      );
}

/// Progress of one achievement for display.
class AchievementProgress {
  const AchievementProgress({required this.definition, required this.current, this.unlocked});

  final AchievementDefinition definition;
  final int current;
  final UnlockedAchievement? unlocked;

  bool get isUnlocked => unlocked != null;
  double get fraction => (current / definition.threshold).clamp(0.0, 1.0);
}
