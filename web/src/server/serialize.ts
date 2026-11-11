import type { ActivityRow, UserRow } from "./db/schema";

export type UserSummary = { id: string; username: string; displayName: string };

export const toUserSummary = (user: UserSummary): UserSummary => ({
  id: user.id,
  username: user.username,
  displayName: user.displayName,
});

export const toMe = (user: UserRow) => ({
  ...toUserSummary(user),
  email: user.email,
  bio: user.bio,
  weeklyGoalMinutes: user.weeklyGoalMinutes,
  defaultVisibility: user.defaultVisibility,
  createdAt: user.createdAt.toISOString(),
});
export type Me = ReturnType<typeof toMe>;

export const toPublicUser = (user: UserRow) => ({
  ...toUserSummary(user),
  bio: user.bio,
  createdAt: user.createdAt.toISOString(),
});

export type ActivityListRow = {
  activity: Omit<ActivityRow, "route"> & { route?: [number, number][] | null };
  user: UserSummary;
  hasRoute: boolean;
  kudosCount: number;
  commentCount: number;
  hasKudoed: boolean;
};

export function toActivity(row: ActivityListRow, options: { includeRoute?: boolean } = {}) {
  const a = row.activity;
  return {
    id: a.id,
    clientId: a.clientId,
    user: toUserSummary(row.user),
    type: a.type,
    title: a.title,
    notes: a.notes,
    startedAt: a.startedAt.toISOString(),
    durationSeconds: a.durationSeconds,
    distanceMeters: a.distanceMeters,
    elevationGainMeters: a.elevationGainMeters,
    activeEnergyKcal: a.activeEnergyKcal,
    avgHeartRate: a.avgHeartRate,
    maxHeartRate: a.maxHeartRate,
    source: a.source,
    visibility: a.visibility,
    hasRoute: row.hasRoute,
    ...(options.includeRoute ? { route: a.route ?? null } : {}),
    kudosCount: row.kudosCount,
    commentCount: row.commentCount,
    hasKudoed: row.hasKudoed,
    createdAt: a.createdAt.toISOString(),
  };
}
export type ActivityDto = ReturnType<typeof toActivity> & { route?: [number, number][] | null };
