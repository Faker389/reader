/**
 * Authoritative achievement rules. Ids and thresholds must match
 * lib/domain/achievements/achievement_catalog.dart in the app; the client's
 * copy is only used for instant, provisional feedback.
 */
export type Metric =
  | "totalWords"
  | "sessions"
  | "highestWpm"
  | "booksCompleted"
  | "longestStreak"
  | "totalSeconds";

export interface AchievementRule {
  id: string;
  metric: Metric;
  threshold: number;
}

export const ACHIEVEMENTS: readonly AchievementRule[] = [
  { id: "first_words", metric: "totalWords", threshold: 1000 },
  { id: "getting_started", metric: "sessions", threshold: 1 },
  { id: "speed_reader", metric: "highestWpm", threshold: 300 },
  { id: "fast_lane", metric: "highestWpm", threshold: 500 },
  { id: "lightning", metric: "highestWpm", threshold: 750 },
  { id: "bookworm", metric: "totalWords", threshold: 100_000 },
  { id: "million_words", metric: "totalWords", threshold: 1_000_000 },
  { id: "first_book", metric: "booksCompleted", threshold: 1 },
  { id: "three_books", metric: "booksCompleted", threshold: 3 },
  { id: "streak_7", metric: "longestStreak", threshold: 7 },
  { id: "streak_30", metric: "longestStreak", threshold: 30 },
  { id: "ten_hours", metric: "totalSeconds", threshold: 10 * 60 * 60 },
];

export type MetricValues = Record<Metric, number>;

export function earnedAchievements(values: MetricValues): string[] {
  return ACHIEVEMENTS.filter((a) => values[a.metric] >= a.threshold).map((a) => a.id);
}
