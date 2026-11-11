import type { Week } from "@/components/charts";
import type { Day } from "@/components/week-goal";

/**
 * Sample data for the interface fragment on the logged-out start page. The week total is the sum
 * of the days, and the last column of the chart is that same total.
 */
export const SAMPLE_GOAL = 150;

export const SAMPLE_DAYS: Day[] = [
  { day: "2026-11-09", durationSeconds: 32 * 60, isToday: false },
  { day: "2026-11-10", durationSeconds: 0, isToday: false },
  { day: "2026-11-11", durationSeconds: 45 * 60, isToday: false },
  { day: "2026-11-12", durationSeconds: 28 * 60, isToday: true },
  { day: "2026-11-13", durationSeconds: 0, isToday: false },
  { day: "2026-11-14", durationSeconds: 0, isToday: false },
  { day: "2026-11-15", durationSeconds: 0, isToday: false },
];

export const SAMPLE_WEEK_SECONDS = SAMPLE_DAYS.reduce((sum, day) => sum + day.durationSeconds, 0);

const earlier: [string, number, number, number][] = [
  ["2026-09-21", 95, 11.2, 2],
  ["2026-09-28", 140, 18.4, 3],
  ["2026-10-05", 165, 21.0, 4],
  ["2026-10-12", 70, 8.1, 2],
  ["2026-10-19", 155, 19.6, 3],
  ["2026-10-26", 180, 24.3, 4],
  ["2026-11-02", 120, 14.9, 3],
];

export const SAMPLE_WEEKS: Week[] = [
  ...earlier.map(([weekStart, minutes, km, count]) => ({
    weekStart,
    durationSeconds: minutes * 60,
    distanceMeters: km * 1000,
    count,
  })),
  { weekStart: "2026-11-09", durationSeconds: SAMPLE_WEEK_SECONDS, distanceMeters: 13_900, count: 3 },
];

/** A loop of about five kilometres, as [lat, lon]. */
export const SAMPLE_ROUTE: [number, number][] = Array.from({ length: 48 }, (_, i) => {
  const t = (i / 47) * Math.PI * 2;
  const r = 1 + 0.22 * Math.sin(3 * t) + 0.1 * Math.cos(5 * t);
  return [52.358 + 0.0062 * r * Math.sin(t), 4.868 + 0.0125 * r * Math.cos(t)];
});

/** The starting grid of the sample week: the same shape the leaderboard endpoint returns. */
export const SAMPLE_BOARD = {
  metric: "duration" as const,
  weekStart: "2026-11-09",
  entries: [
    { rank: 1, user: { id: "s1", username: "noor", displayName: "Noor" }, value: 192 * 60, count: 4, isMe: false },
    { rank: 2, user: { id: "s2", username: "sanne", displayName: "Sanne" }, value: SAMPLE_WEEK_SECONDS, count: 3, isMe: true },
    { rank: 3, user: { id: "s3", username: "daan", displayName: "Daan" }, value: 91 * 60, count: 2, isMe: false },
  ],
};
