import { and, desc, eq, getTableColumns, inArray, lt, or, sql, type SQL } from "drizzle-orm";
import type { z } from "zod";
import type { ActivityInput, activityPatchSchema } from "@/lib/schemas";
import { getDb } from "./db";
import { activities, comments, kudos, users, type UserRow } from "./db/schema";
import { notFound } from "./errors";
import { areFriends, friendIdsOf, getRelation } from "./friends";
import { toActivity, toPublicUser, toUserSummary, type ActivityListRow } from "./serialize";

// Routes can be large, so list queries leave the column out and only report whether one exists.
const { route: _route, ...activityColumnsWithoutRoute } = getTableColumns(activities);

const listColumns = (viewerId: string | null, withRoute = false) => ({
  activity: withRoute ? getTableColumns(activities) : activityColumnsWithoutRoute,
  user: { id: users.id, username: users.username, displayName: users.displayName },
  hasRoute: sql<boolean>`${activities.route} is not null`,
  kudosCount: sql<number>`(select count(*)::int from kudos k where k.activity_id = ${activities.id})`,
  commentCount: sql<number>`(select count(*)::int from comments c where c.activity_id = ${activities.id})`,
  hasKudoed: viewerId
    ? sql<boolean>`exists (select 1 from kudos k where k.activity_id = ${activities.id} and k.user_id = ${viewerId})`
    : sql<boolean>`false`,
});

/** Thins a route to at most `max` points; enough for a thumbnail. */
function routePreview(route: [number, number][] | null | undefined, max = 60): [number, number][] | null {
  if (!route || route.length < 2) return null;
  if (route.length <= max) return route;
  const step = (route.length - 1) / (max - 1);
  return Array.from({ length: max }, (_, i) => route[Math.round(i * step)]);
}

async function selectActivities(
  viewerId: string | null,
  where: SQL | undefined,
  limit: number,
  options: { withRoutePreview?: boolean } = {},
) {
  const rows = await getDb()
    .select(listColumns(viewerId, options.withRoutePreview))
    .from(activities)
    .innerJoin(users, eq(users.id, activities.userId))
    .where(where)
    .orderBy(desc(activities.startedAt), desc(activities.id))
    .limit(limit + 1);
  const page = rows.slice(0, limit) as ActivityListRow[];
  return {
    activities: page.map((row) => ({
      ...toActivity(row),
      // Only the website asks for this; the API contract keeps routes out of lists.
      ...(options.withRoutePreview ? { routePreview: routePreview(row.activity.route) } : {}),
    })),
    nextCursor: rows.length > limit ? page[page.length - 1].activity.startedAt.toISOString() : null,
  };
}

const beforeCursor = (before?: Date) => (before ? lt(activities.startedAt, before) : undefined);

type PageOptions = { before?: Date; limit: number; withRoutePreview?: boolean };

export function listOwnActivities(userId: string, page: PageOptions) {
  return selectActivities(userId, and(eq(activities.userId, userId), beforeCursor(page.before)), page.limit, page);
}

/** My own activities plus what my friends share with friends or publicly. */
export function listFeed(userId: string, page: PageOptions) {
  const visible = or(
    eq(activities.userId, userId),
    and(
      inArray(activities.visibility, ["friends", "public"]),
      sql`${activities.userId} in ${friendIdsOf(userId)}`,
    ),
  );
  return selectActivities(userId, and(visible, beforeCursor(page.before)), page.limit, page);
}

/** Activities of `owner` that `viewerId` (null = not logged in) is allowed to see. */
function visibleActivitiesOf(ownerId: string, relation: string): SQL | undefined {
  if (relation === "self") return eq(activities.userId, ownerId);
  const allowed = relation === "friends" ? (["friends", "public"] as const) : (["public"] as const);
  return and(eq(activities.userId, ownerId), inArray(activities.visibility, [...allowed]));
}

export async function getProfile(
  viewerId: string | null,
  username: string,
  options: { withRoutePreview?: boolean } = {},
) {
  const db = getDb();
  const [user] = await db.select().from(users).where(eq(users.username, username.toLowerCase())).limit(1);
  if (!user) throw notFound("Deze gebruiker bestaat niet.");
  const { relation, requestId } = await getRelation(viewerId, user.id);
  const where = visibleActivitiesOf(user.id, relation);

  const [[stats], list] = await Promise.all([
    db
      .select({
        count: sql<number>`count(*)::int`,
        durationSeconds: sql<number>`coalesce(sum(${activities.durationSeconds}), 0)::int`,
        distanceMeters: sql<number>`coalesce(sum(${activities.distanceMeters}), 0)::float8`,
      })
      .from(activities)
      .where(where),
    selectActivities(viewerId, where, 20, { withRoutePreview: options.withRoutePreview }),
  ]);

  return { user: toPublicUser(user), relation, requestId, stats, activities: list.activities };
}

async function loadActivity(viewerId: string | null, activityId: string) {
  const [row] = await getDb()
    .select(listColumns(viewerId, true))
    .from(activities)
    .innerJoin(users, eq(users.id, activities.userId))
    .where(eq(activities.id, activityId))
    .limit(1);
  return row as ActivityListRow | undefined;
}

async function canView(viewerId: string | null, row: ActivityListRow): Promise<boolean> {
  const { userId, visibility } = row.activity;
  if (viewerId === userId || visibility === "public") return true;
  if (visibility === "friends" && viewerId) return areFriends(viewerId, userId);
  return false;
}

/** Throws not_found for activities the viewer may not see, so their existence does not leak. */
export async function requireVisibleActivity(viewerId: string | null, activityId: string) {
  const row = await loadActivity(viewerId, activityId);
  if (!row || !(await canView(viewerId, row))) throw notFound("Deze activiteit bestaat niet (meer).");
  return row;
}

export async function getActivityDetail(viewerId: string | null, activityId: string) {
  const row = await requireVisibleActivity(viewerId, activityId);
  const commentRows = await getDb()
    .select({
      id: comments.id,
      body: comments.body,
      createdAt: comments.createdAt,
      user: { id: users.id, username: users.username, displayName: users.displayName },
    })
    .from(comments)
    .innerJoin(users, eq(users.id, comments.userId))
    .where(eq(comments.activityId, activityId))
    .orderBy(comments.createdAt);
  return {
    activity: toActivity(row, { includeRoute: true }),
    comments: commentRows.map((c) => ({
      id: c.id,
      user: toUserSummary(c.user),
      body: c.body,
      createdAt: c.createdAt.toISOString(),
    })),
  };
}

function valuesFromInput(user: UserRow, input: ActivityInput) {
  return {
    userId: user.id,
    clientId: input.clientId.toLowerCase(),
    type: input.type,
    title: input.title ?? "",
    notes: input.notes ?? "",
    startedAt: input.startedAt,
    durationSeconds: input.durationSeconds,
    distanceMeters: input.distanceMeters ?? null,
    elevationGainMeters: input.elevationGainMeters ?? null,
    activeEnergyKcal: input.activeEnergyKcal ?? null,
    avgHeartRate: input.avgHeartRate ?? null,
    maxHeartRate: input.maxHeartRate ?? null,
    source: input.source,
    visibility: input.visibility ?? user.defaultVisibility,
    route: input.route && input.route.length >= 2 ? input.route : null,
  };
}

/**
 * Inserts the activity, or updates the one this device uploaded earlier under the same clientId.
 * On update, anything the upload leaves out (title, notes, visibility) keeps its stored value, so
 * a re-sync from the phone never undoes an edit made on the website.
 */
export async function upsertActivity(user: UserRow, input: ActivityInput) {
  const values = valuesFromInput(user, input);
  const keep = <T>(provided: unknown, column: T, next: T) => (provided === undefined ? column : next);
  const [row] = await getDb()
    .insert(activities)
    .values(values)
    .onConflictDoUpdate({
      target: [activities.userId, activities.clientId],
      set: {
        type: values.type,
        startedAt: values.startedAt,
        durationSeconds: values.durationSeconds,
        distanceMeters: values.distanceMeters,
        elevationGainMeters: values.elevationGainMeters,
        activeEnergyKcal: values.activeEnergyKcal,
        avgHeartRate: values.avgHeartRate,
        maxHeartRate: values.maxHeartRate,
        source: values.source,
        title: keep(input.title, sql`${activities.title}`, sql`${values.title}`),
        notes: keep(input.notes, sql`${activities.notes}`, sql`${values.notes}`),
        visibility: keep(input.visibility, sql`${activities.visibility}`, sql`${values.visibility}`),
        route: input.route === undefined ? sql`${activities.route}` : values.route,
        updatedAt: new Date(),
      },
    })
    .returning({ id: activities.id, created: sql<boolean>`xmax = 0` });
  const loaded = await loadActivity(user.id, row.id);
  return { activity: toActivity(loaded!), created: row.created };
}

export async function upsertActivities(user: UserRow, inputs: ActivityInput[]) {
  const results = [];
  for (const input of inputs) results.push((await upsertActivity(user, input)).activity);
  return results;
}

export async function updateActivity(userId: string, activityId: string, patch: z.infer<typeof activityPatchSchema>) {
  const [row] = await getDb()
    .update(activities)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(activities.id, activityId), eq(activities.userId, userId)))
    .returning({ id: activities.id });
  if (!row) throw notFound("Deze activiteit bestaat niet (meer).");
  return toActivity((await loadActivity(userId, activityId))!);
}

export async function deleteActivity(userId: string, activityId: string) {
  const [row] = await getDb()
    .delete(activities)
    .where(and(eq(activities.id, activityId), eq(activities.userId, userId)))
    .returning({ id: activities.id });
  if (!row) throw notFound("Deze activiteit bestaat niet (meer).");
}

async function kudosState(userId: string, activityId: string) {
  const [state] = await getDb()
    .select({
      kudosCount: sql<number>`count(*)::int`,
      hasKudoed: sql<boolean>`coalesce(bool_or(${kudos.userId} = ${userId}), false)`,
    })
    .from(kudos)
    .where(eq(kudos.activityId, activityId));
  return state;
}

export async function setKudos(userId: string, activityId: string, on: boolean) {
  await requireVisibleActivity(userId, activityId);
  const db = getDb();
  if (on) await db.insert(kudos).values({ activityId, userId }).onConflictDoNothing();
  else await db.delete(kudos).where(and(eq(kudos.activityId, activityId), eq(kudos.userId, userId)));
  return kudosState(userId, activityId);
}

export async function addComment(user: UserRow, activityId: string, body: string) {
  await requireVisibleActivity(user.id, activityId);
  const [row] = await getDb().insert(comments).values({ activityId, userId: user.id, body }).returning();
  return { id: row.id, user: toUserSummary(user), body: row.body, createdAt: row.createdAt.toISOString() };
}

/** A comment can be removed by its author or by the owner of the activity. */
export async function deleteComment(userId: string, commentId: string) {
  const db = getDb();
  const [row] = await db
    .select({ id: comments.id, authorId: comments.userId, ownerId: activities.userId })
    .from(comments)
    .innerJoin(activities, eq(activities.id, comments.activityId))
    .where(eq(comments.id, commentId))
    .limit(1);
  if (!row || (row.authorId !== userId && row.ownerId !== userId)) throw notFound("Deze reactie bestaat niet (meer).");
  await db.delete(comments).where(eq(comments.id, commentId));
}
