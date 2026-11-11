import { and, asc, eq, ilike, ne, or, sql } from "drizzle-orm";
import { getDb } from "./db";
import { friendships, users, type UserRow } from "./db/schema";
import { ApiError, forbidden, isUniqueViolation, notFound } from "./errors";
import { toUserSummary, type UserSummary } from "./serialize";

export type Relation = "self" | "friends" | "outgoing" | "incoming" | "none";

/** SQL list of the ids of everyone `userId` is friends with. */
export const friendIdsOf = (userId: string) => sql`(
  select case when f.requester_id = ${userId} then f.addressee_id else f.requester_id end
  from friendships f
  where f.status = 'accepted' and (f.requester_id = ${userId} or f.addressee_id = ${userId})
)`;

const between = (a: string, b: string) =>
  or(
    and(eq(friendships.requesterId, a), eq(friendships.addresseeId, b)),
    and(eq(friendships.requesterId, b), eq(friendships.addresseeId, a)),
  );

export async function getRelation(
  viewerId: string | null,
  otherId: string,
): Promise<{ relation: Relation; requestId: string | null }> {
  if (!viewerId) return { relation: "none", requestId: null };
  if (viewerId === otherId) return { relation: "self", requestId: null };
  const [row] = await getDb().select().from(friendships).where(between(viewerId, otherId)).limit(1);
  if (!row) return { relation: "none", requestId: null };
  if (row.status === "accepted") return { relation: "friends", requestId: null };
  return { relation: row.requesterId === viewerId ? "outgoing" : "incoming", requestId: row.id };
}

export async function areFriends(a: string, b: string): Promise<boolean> {
  return (await getRelation(a, b)).relation === "friends";
}

export async function listFriends(userId: string) {
  const db = getDb();
  const rows = await db
    .select({
      id: friendships.id,
      status: friendships.status,
      requesterId: friendships.requesterId,
      createdAt: friendships.createdAt,
      user: { id: users.id, username: users.username, displayName: users.displayName },
    })
    .from(friendships)
    .innerJoin(
      users,
      sql`${users.id} = case when ${friendships.requesterId} = ${userId} then ${friendships.addresseeId} else ${friendships.requesterId} end`,
    )
    .where(or(eq(friendships.requesterId, userId), eq(friendships.addresseeId, userId)))
    .orderBy(asc(users.displayName));

  const friends: UserSummary[] = [];
  const incoming: { id: string; user: UserSummary; createdAt: string }[] = [];
  const outgoing: { id: string; user: UserSummary; createdAt: string }[] = [];
  for (const row of rows) {
    if (row.status === "accepted") friends.push(toUserSummary(row.user));
    else {
      const request = { id: row.id, user: toUserSummary(row.user), createdAt: row.createdAt.toISOString() };
      (row.requesterId === userId ? outgoing : incoming).push(request);
    }
  }
  return { friends, incoming, outgoing };
}

export async function sendFriendRequest(me: UserRow, username: string): Promise<"requested" | "friends"> {
  const db = getDb();
  const [other] = await db.select().from(users).where(eq(users.username, username)).limit(1);
  if (!other) throw notFound("Deze gebruiker bestaat niet.");
  if (other.id === me.id) throw new ApiError(400, "invalid_request", "Je kunt jezelf niet uitnodigen.");

  const accept = (id: string) =>
    db.update(friendships).set({ status: "accepted", acceptedAt: new Date() }).where(eq(friendships.id, id));

  for (let attempt = 0; attempt < 2; attempt++) {
    const [existing] = await db.select().from(friendships).where(between(me.id, other.id)).limit(1);
    if (existing) {
      if (existing.status === "accepted") return "friends";
      if (existing.requesterId === me.id) return "requested";
      // They had already invited me: asking back means yes.
      await accept(existing.id);
      return "friends";
    }
    try {
      await db.insert(friendships).values({ requesterId: me.id, addresseeId: other.id });
      return "requested";
    } catch (error) {
      // Both sent a request at the same moment; look again and accept theirs.
      if (!isUniqueViolation(error)) throw error;
    }
  }
  throw new ApiError(409, "conflict", "Probeer het opnieuw.");
}

export async function acceptFriendRequest(userId: string, requestId: string) {
  const [row] = await getDb()
    .update(friendships)
    .set({ status: "accepted", acceptedAt: new Date() })
    .where(
      and(eq(friendships.id, requestId), eq(friendships.addresseeId, userId), eq(friendships.status, "pending")),
    )
    .returning();
  if (!row) throw notFound("Dit verzoek bestaat niet meer.");
}

/** Decline (as addressee) or withdraw (as requester) a pending request. */
export async function deleteFriendRequest(userId: string, requestId: string) {
  const db = getDb();
  const [row] = await db.select().from(friendships).where(eq(friendships.id, requestId)).limit(1);
  if (!row || row.status !== "pending") throw notFound("Dit verzoek bestaat niet meer.");
  if (row.requesterId !== userId && row.addresseeId !== userId) throw forbidden();
  await db.delete(friendships).where(eq(friendships.id, requestId));
}

export async function removeFriend(userId: string, otherId: string) {
  await getDb()
    .delete(friendships)
    .where(and(between(userId, otherId), eq(friendships.status, "accepted")));
}

export async function searchUsers(viewerId: string, query: string) {
  const q = query.trim().toLowerCase().replace(/^@/, "");
  if (q.length < 2) return [];
  const pattern = `%${q.replace(/[\\%_]/g, "\\$&")}%`;
  const rows = await getDb()
    .select({
      id: users.id,
      username: users.username,
      displayName: users.displayName,
      status: friendships.status,
      requesterId: friendships.requesterId,
    })
    .from(users)
    .leftJoin(
      friendships,
      sql`(${friendships.requesterId} = ${viewerId} and ${friendships.addresseeId} = ${users.id})
        or (${friendships.addresseeId} = ${viewerId} and ${friendships.requesterId} = ${users.id})`,
    )
    .where(and(ne(users.id, viewerId), or(ilike(users.username, pattern), ilike(users.displayName, pattern))))
    .orderBy(sql`(${users.username} = ${q}) desc`, asc(users.username))
    .limit(20);

  return rows.map((row) => ({
    ...toUserSummary(row),
    relation: (row.status === null
      ? "none"
      : row.status === "accepted"
        ? "friends"
        : row.requesterId === viewerId
          ? "outgoing"
          : "incoming") as Relation,
  }));
}
