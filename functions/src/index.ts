import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import * as authV1 from "firebase-functions/v1";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { MetricValues, earnedAchievements } from "./achievements";
import { LIMITS, computeStreaks, validateSession } from "./stats";

initializeApp();

// TODO(firebase): choose the region closest to your users and keep it in sync
// with your Firestore location.
const REGION = "europe-west1";

interface Summary {
  totalSeconds: number;
  totalWords: number;
  sessionsCount: number;
  highestWpm: number;
  longestSessionSeconds: number;
  completedBookIds: string[];
  metDays: string[];
}

const EMPTY_SUMMARY: Summary = {
  totalSeconds: 0,
  totalWords: 0,
  sessionsCount: 0,
  highestWpm: 0,
  longestSessionSeconds: 0,
  completedBookIds: [],
  metDays: [],
};

/**
 * The server-side source of truth for statistics, streaks and achievements.
 *
 * Runs once per new session log. It re-validates the data, folds it into
 * per-day and lifetime aggregates inside a transaction, and unlocks any
 * achievements the *server* totals now satisfy. A marker document makes the
 * trigger idempotent, since Cloud Functions may deliver an event twice.
 */
export const onSessionCreated = onDocumentCreated(
  { document: "users/{uid}/sessions/{sessionId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const { uid, sessionId } = event.params;
    const db = getFirestore();
    const userRef = db.doc(`users/${uid}`);
    const markerRef = userRef.collection("processedSessions").doc(sessionId);

    const validation = validateSession(snapshot.data(), Date.now());
    if (!validation.ok) {
      logger.warn("Rejected session", { uid, sessionId, reason: validation.reason });
      await markerRef.set({ rejected: true, reason: validation.reason, at: FieldValue.serverTimestamp() });
      return;
    }
    const session = validation.session;
    const summaryRef = userRef.collection("statistics").doc("summary");
    const dayRef = userRef.collection("statistics").doc(session.localDate);
    const achievementsRef = userRef.collection("achievements");

    const unlocked = await db.runTransaction(async (tx) => {
      const [marker, summarySnap, daySnap, achievementsSnap] = await Promise.all([
        tx.get(markerRef),
        tx.get(summaryRef),
        tx.get(dayRef),
        tx.get(achievementsRef),
      ]);
      if (marker.exists) return [] as string[];

      const summary: Summary = { ...EMPTY_SUMMARY, ...(summarySnap.data() as Partial<Summary> | undefined) };
      summary.totalSeconds += session.duration;
      summary.totalWords += session.wordsRead;
      summary.sessionsCount += 1;
      summary.longestSessionSeconds = Math.max(summary.longestSessionSeconds, session.duration);
      if (session.duration >= LIMITS.speedRecordMinSeconds) {
        summary.highestWpm = Math.max(summary.highestWpm, session.averageWpm);
      }
      if (session.bookCompleted && !summary.completedBookIds.includes(session.bookId)) {
        summary.completedBookIds = [...summary.completedBookIds, session.bookId];
      }

      const day = daySnap.data() ?? {};
      const daySeconds = (Number(day.seconds) || 0) + session.duration;
      // A day's goal is the goal in force for the latest session that day.
      const goalMet = daySeconds >= session.goalMinutes * 60;
      if (goalMet && !summary.metDays.includes(session.localDate)) {
        summary.metDays = [...summary.metDays, session.localDate];
      }
      const streak = computeStreaks(summary.metDays);

      const values: MetricValues = {
        totalWords: summary.totalWords,
        sessions: summary.sessionsCount,
        highestWpm: summary.highestWpm,
        booksCompleted: summary.completedBookIds.length,
        longestStreak: streak.longest,
        totalSeconds: summary.totalSeconds,
      };
      const existing = new Set(achievementsSnap.docs.map((d) => d.id));
      const newlyUnlocked = earnedAchievements(values).filter((id) => !existing.has(id));

      tx.set(markerRef, { at: FieldValue.serverTimestamp() });
      tx.set(summaryRef, { ...summary, updatedAt: FieldValue.serverTimestamp() });
      tx.set(dayRef, {
        date: session.localDate,
        seconds: daySeconds,
        words: (Number(day.words) || 0) + session.wordsRead,
        sessions: (Number(day.sessions) || 0) + 1,
        goalMinutes: session.goalMinutes,
        goalMet,
      });
      for (const id of newlyUnlocked) {
        tx.set(achievementsRef.doc(id), { id, unlockedAt: FieldValue.serverTimestamp(), verified: true });
      }
      tx.set(
        userRef,
        {
          totalWordsRead: summary.totalWords,
          totalReadingTime: summary.totalSeconds,
          booksCompleted: summary.completedBookIds.length,
          currentStreak: streak.current,
          longestStreak: streak.longest,
          lastReadingDate: streak.lastMetDay ? Timestamp.fromDate(new Date(`${streak.lastMetDay}T12:00:00Z`)) : null,
          statsUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return newlyUnlocked;
    });

    if (unlocked.length > 0) logger.info("Achievements unlocked", { uid, unlocked });
  },
);

/**
 * Safety net for account deletion: the app deletes the user's data before
 * deleting the auth record, but if that was interrupted this removes
 * everything that remains, including server-only collections.
 */
export const onUserDeleted = authV1.region(REGION).auth.user().onDelete(async (user) => {
  const db = getFirestore();
  await db.recursiveDelete(db.doc(`users/${user.uid}`));
  try {
    await getStorage().bucket().deleteFiles({ prefix: `users/${user.uid}/` });
  } catch (error) {
    logger.warn("Storage cleanup failed", { uid: user.uid, error: String(error) });
  }
  logger.info("Deleted user data", { uid: user.uid });
});
