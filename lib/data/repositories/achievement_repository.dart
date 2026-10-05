import '../../domain/achievements/achievement_catalog.dart';
import '../../domain/achievements/achievement_evaluator.dart';
import '../../domain/models/achievement.dart';
import '../../domain/stats/reading_stats.dart';
import '../local/json_store.dart';

/// Locally evaluated achievements give instant feedback. The Cloud Function
/// re-evaluates from session logs and writes the authoritative records, which
/// arrive through sync with `verified: true`.
class AchievementRepository {
  AchievementRepository({required JsonStore<UnlockedAchievement> store}) : _store = store;

  final JsonStore<UnlockedAchievement> _store;

  Stream<Map<String, UnlockedAchievement>> watch() =>
      _store.watch().map((list) => {for (final a in list) a.id: a});

  Map<String, UnlockedAchievement> get unlocked => {for (final a in _store.all) a.id: a};

  /// Unlocks anything newly earned and returns those definitions so the UI
  /// can celebrate them.
  Future<List<AchievementDefinition>> evaluate(ReadingStats stats) async {
    final earned = AchievementEvaluator.earned(stats);
    final now = DateTime.now();
    final fresh = [
      for (final id in earned)
        if (!_store.contains(id)) UnlockedAchievement(id: id, unlockedAt: now),
    ];
    await _store.putAll(fresh);
    return [
      for (final a in fresh)
        if (AchievementCatalog.byId(a.id) case final definition?) definition,
    ];
  }
}
