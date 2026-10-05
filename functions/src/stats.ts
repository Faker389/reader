/** Pure helpers shared by the triggers, kept free of Firebase imports. */

/** Must match SessionConstants in the app. */
export const LIMITS = {
  maxSessionSeconds: 6 * 60 * 60,
  maxPlausibleWpm: 1500,
  speedRecordMinSeconds: 60,
  clockSkewMillis: 5 * 60 * 1000,
} as const;

export interface SessionInput {
  bookId: string;
  startTime: number;
  endTime: number;
  duration: number;
  wordsRead: number;
  averageWpm: number;
  localDate: string;
  goalMinutes: number;
  bookCompleted: boolean;
}

export type Validation = { ok: true; session: SessionInput } | { ok: false; reason: string };

function int(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? Math.round(value) : null;
}

/**
 * Re-validates a session independently of the security rules and rejects
 * physically implausible data (e.g. more words than the time allows).
 */
export function validateSession(data: Record<string, unknown>, now: number): Validation {
  const startTime = int(data.startTime);
  const endTime = int(data.endTime);
  const duration = int(data.duration);
  const wordsRead = int(data.wordsRead);
  const averageWpm = int(data.averageWpm);
  const goalMinutes = int(data.goalMinutes);
  const { bookId, localDate, bookCompleted } = data;

  if (startTime === null || endTime === null || duration === null || wordsRead === null ||
      averageWpm === null || goalMinutes === null) {
    return { ok: false, reason: "missing numeric fields" };
  }
  if (typeof bookId !== "string" || typeof localDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
    return { ok: false, reason: "invalid identifiers" };
  }
  if (duration <= 0 || duration > LIMITS.maxSessionSeconds) return { ok: false, reason: "duration out of range" };
  if (endTime < startTime || endTime > now + LIMITS.clockSkewMillis) return { ok: false, reason: "bad timestamps" };
  // Active reading time can't exceed wall-clock time.
  if (duration * 1000 > endTime - startTime + 5000) return { ok: false, reason: "duration exceeds wall time" };
  if (wordsRead < 0 || wordsRead > (duration / 60) * LIMITS.maxPlausibleWpm + 50) {
    return { ok: false, reason: "implausible word count" };
  }
  if (averageWpm <= 0 || averageWpm > LIMITS.maxPlausibleWpm) return { ok: false, reason: "implausible speed" };

  return {
    ok: true,
    session: {
      bookId,
      startTime,
      endTime,
      duration,
      wordsRead,
      averageWpm,
      localDate,
      goalMinutes: Math.min(Math.max(goalMinutes, 1), 600),
      bookCompleted: bookCompleted === true,
    },
  };
}

function shiftDay(day: string, delta: number): string {
  const [y, m, d] = day.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d + delta));
  return date.toISOString().slice(0, 10);
}

/**
 * Streaks from the set of calendar days on which the goal was met. Days are
 * the user's *local* dates as recorded by the client, so time zones and DST
 * don't split or merge days. `current` is the run ending at the latest met day;
 * the client decides whether that run is still alive relative to its "today".
 */
export function computeStreaks(metDays: string[]): { current: number; longest: number; lastMetDay: string | null } {
  if (metDays.length === 0) return { current: 0, longest: 0, lastMetDay: null };
  const days = [...new Set(metDays)].sort();
  let longest = 1;
  let run = 1;
  for (let i = 1; i < days.length; i++) {
    run = days[i] === shiftDay(days[i - 1], 1) ? run + 1 : 1;
    longest = Math.max(longest, run);
  }
  return { current: run, longest, lastMetDay: days[days.length - 1] };
}
