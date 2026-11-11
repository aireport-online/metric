import { sql } from "drizzle-orm";
import type { ActivityType } from "@/lib/constants";
import { getDb } from "./db";
import type { UserRow } from "./db/schema";
import { friendIdsOf } from "./friends";
import { toUserSummary } from "./serialize";

const DAY_MS = 24 * 3600 * 1000;

/** Monday of the week `startedAt` falls in, as a date in the given time zone. */
const weekOf = (column: ReturnType<typeof sql>, tz: string) => sql`date_trunc('week', ${column} at time zone ${tz})::date`;
const currentWeek = (tz: string) => sql`date_trunc('week', now() at time zone ${tz})::date`;

async function rows<T>(query: ReturnType<typeof sql>): Promise<T[]> {
  const result = await getDb().execute(query);
  return result.rows as T[];
}

/** Counts back from the current week; a week without activities ends the streak. */
export function streakFromWeeks(activeWeeks: string[], currentWeekStart: string): number {
  const active = new Set(activeWeeks);
  let cursor = new Date(`${currentWeekStart}T00:00:00Z`).getTime();
  // The running week only counts once it has an activity; it never breaks the streak.
  if (!active.has(currentWeekStart)) cursor -= 7 * DAY_MS;
  let streak = 0;
  while (active.has(new Date(cursor).toISOString().slice(0, 10))) {
    streak += 1;
    cursor -= 7 * DAY_MS;
  }
  return streak;
}

export async function getStats(user: UserRow, weeks: number, tz: string) {
  const started = sql`a.started_at`;
  const [weekly, byType, [totals], activeWeeks, [{ current_week: currentWeekStart }]] = await Promise.all([
    rows<{ week_start: string; duration_seconds: number; distance_meters: number; kcal: number; count: number }>(sql`
      select to_char(w.week_start, 'YYYY-MM-DD') as week_start,
             coalesce(sum(a.duration_seconds), 0)::int as duration_seconds,
             coalesce(sum(a.distance_meters), 0)::float8 as distance_meters,
             coalesce(sum(a.active_energy_kcal), 0)::float8 as kcal,
             count(a.id)::int as count
      from (select (${currentWeek(tz)} - n * 7)::date as week_start from generate_series(0, ${weeks - 1}) n) w
      left join activities a
        on a.user_id = ${user.id} and ${weekOf(started, tz)} = w.week_start
      group by w.week_start
      order by w.week_start`),
    rows<{ type: ActivityType; count: number; duration_seconds: number; distance_meters: number }>(sql`
      select a.type,
             count(*)::int as count,
             sum(a.duration_seconds)::int as duration_seconds,
             coalesce(sum(a.distance_meters), 0)::float8 as distance_meters
      from activities a
      where a.user_id = ${user.id}
        and ${weekOf(started, tz)} >= (${currentWeek(tz)} - ${(weeks - 1) * 7}::int)
      group by a.type
      order by duration_seconds desc`),
    rows<{ count: number; duration_seconds: number; distance_meters: number }>(sql`
      select count(*)::int as count,
             coalesce(sum(a.duration_seconds), 0)::int as duration_seconds,
             coalesce(sum(a.distance_meters), 0)::float8 as distance_meters
      from activities a where a.user_id = ${user.id}`),
    rows<{ week_start: string }>(sql`
      select distinct to_char(${weekOf(started, tz)}, 'YYYY-MM-DD') as week_start
      from activities a where a.user_id = ${user.id}`),
    rows<{ current_week: string }>(sql`select to_char(${currentWeek(tz)}, 'YYYY-MM-DD') as current_week`),
  ]);

  const thisWeek = weekly[weekly.length - 1];
  return {
    thisWeek: {
      durationSeconds: thisWeek.duration_seconds,
      distanceMeters: thisWeek.distance_meters,
      activeEnergyKcal: thisWeek.kcal,
      count: thisWeek.count,
      goalMinutes: user.weeklyGoalMinutes,
    },
    weekly: weekly.map((week) => ({
      weekStart: week.week_start,
      durationSeconds: week.duration_seconds,
      distanceMeters: week.distance_meters,
      count: week.count,
    })),
    byType: byType.map((entry) => ({
      type: entry.type,
      count: entry.count,
      durationSeconds: entry.duration_seconds,
      distanceMeters: entry.distance_meters,
    })),
    totals: {
      count: totals.count,
      durationSeconds: totals.duration_seconds,
      distanceMeters: totals.distance_meters,
    },
    currentStreakWeeks: streakFromWeeks(
      activeWeeks.map((week) => week.week_start),
      currentWeekStart,
    ),
  };
}
export type Stats = Awaited<ReturnType<typeof getStats>>;

export type LeaderboardMetric = "duration" | "distance" | "count";

/**
 * Me and my friends, ranked on this week's total. Friends' private activities are left out,
 * so the ranking never reveals more than their feed does.
 */
export async function getLeaderboard(user: UserRow, metric: LeaderboardMetric, tz: string) {
  const value = {
    duration: sql`coalesce(sum(a.duration_seconds), 0)::float8`,
    distance: sql`coalesce(sum(a.distance_meters), 0)::float8`,
    count: sql`count(a.id)::float8`,
  }[metric];

  const entries = await rows<{
    id: string;
    username: string;
    display_name: string;
    value: number;
    count: number;
    week_start: string;
  }>(sql`
    select u.id, u.username, u.display_name,
           ${value} as value,
           count(a.id)::int as count,
           to_char(${currentWeek(tz)}, 'YYYY-MM-DD') as week_start
    from users u
    left join activities a
      on a.user_id = u.id
     and ${weekOf(sql`a.started_at`, tz)} = ${currentWeek(tz)}
     and (a.user_id = ${user.id} or a.visibility <> 'private')
    where u.id = ${user.id} or u.id in ${friendIdsOf(user.id)}
    group by u.id
    order by value desc, u.display_name asc`);

  let rank = 0;
  let previous: number | null = null;
  return {
    metric,
    weekStart: entries[0]?.week_start ?? "",
    entries: entries.map((entry, index) => {
      if (entry.value !== previous) rank = index + 1;
      previous = entry.value;
      return {
        rank,
        user: toUserSummary({ id: entry.id, username: entry.username, displayName: entry.display_name }),
        value: entry.value,
        count: entry.count,
        isMe: entry.id === user.id,
      };
    }),
  };
}
export type Leaderboard = Awaited<ReturnType<typeof getLeaderboard>>;
