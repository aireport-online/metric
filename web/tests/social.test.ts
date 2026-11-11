import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { DELETE as unfriend } from "@/app/api/v1/friends/[userId]/route";
import { POST as accept } from "@/app/api/v1/friends/requests/[id]/accept/route";
import { DELETE as dropRequest } from "@/app/api/v1/friends/requests/[id]/route";
import { POST as requestFriend } from "@/app/api/v1/friends/requests/route";
import { GET as friends } from "@/app/api/v1/friends/route";
import { GET as leaderboard } from "@/app/api/v1/leaderboard/route";
import { GET as stats } from "@/app/api/v1/stats/route";
import { GET as search } from "@/app/api/v1/users/search/route";
import { getPool } from "@/server/db";
import { streakFromWeeks } from "@/server/stats";
import { addActivity, befriend, call, resetDb, signUp } from "./helpers";

beforeEach(resetDb);
afterAll(() => getPool().end());

const daysAgo = (days: number) => new Date(Date.now() - days * 24 * 3600_000).toISOString();

describe("friends", () => {
  it("goes from request to accepted friendship", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");

    const sent = await call(requestFriend, { token: sam.token, body: { username: "Kim" } });
    expect(sent.status).toBe(201);
    expect(sent.data.status).toBe("requested");
    // Asking twice does not create a second request.
    expect((await call(requestFriend, { token: sam.token, body: { username: "kim" } })).data.status).toBe("requested");

    const kimsList = (await call(friends, { token: kim.token })).data;
    expect(kimsList.incoming).toHaveLength(1);
    expect(kimsList.incoming[0].user.username).toBe("sam");
    expect((await call(friends, { token: sam.token })).data.outgoing).toHaveLength(1);

    // Only the addressee can accept.
    const requestId = kimsList.incoming[0].id;
    expect((await call(accept, { method: "POST", token: sam.token, params: { id: requestId } })).status).toBe(404);
    expect((await call(accept, { method: "POST", token: kim.token, params: { id: requestId } })).status).toBe(200);

    const after = (await call(friends, { token: sam.token })).data;
    expect(after.friends.map((f: { username: string }) => f.username)).toEqual(["kim"]);
    expect(after.outgoing).toEqual([]);
  });

  it("can decline, withdraw and unfriend", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const alex = await signUp("alex");

    await call(requestFriend, { token: sam.token, body: { username: "kim" } });
    let request = (await call(friends, { token: kim.token })).data.incoming[0];
    // A third person cannot touch the request.
    expect((await call(dropRequest, { method: "DELETE", token: alex.token, params: { id: request.id } })).status).toBe(403);
    expect((await call(dropRequest, { method: "DELETE", token: kim.token, params: { id: request.id } })).status).toBe(204);

    await call(requestFriend, { token: sam.token, body: { username: "kim" } });
    request = (await call(friends, { token: sam.token })).data.outgoing[0];
    expect((await call(dropRequest, { method: "DELETE", token: sam.token, params: { id: request.id } })).status).toBe(204);

    await befriend(sam, kim);
    expect((await call(unfriend, { method: "DELETE", token: kim.token, params: { userId: sam.user.id } })).status).toBe(204);
    expect((await call(friends, { token: sam.token })).data.friends).toEqual([]);
  });

  it("rejects requests to yourself and to unknown users", async () => {
    const sam = await signUp("sam");
    expect((await call(requestFriend, { token: sam.token, body: { username: "sam" } })).status).toBe(400);
    expect((await call(requestFriend, { token: sam.token, body: { username: "ghost" } })).status).toBe(404);
  });

  it("searches by username or name and reports the relation", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    await signUp("kimberly");
    await signUp("alex");
    await befriend(sam, kim);
    await call(requestFriend, { token: sam.token, body: { username: "kimberly" } });

    const { data } = await call(search, { token: sam.token, query: { q: "KIM" } });
    expect(data.users).toEqual([
      expect.objectContaining({ username: "kim", relation: "friends" }),
      expect.objectContaining({ username: "kimberly", relation: "outgoing" }),
    ]);
    expect((await call(search, { token: sam.token, query: { q: "s" } })).data.users).toEqual([]);
    // Wildcards in the query are taken literally.
    expect((await call(search, { token: sam.token, query: { q: "%%" } })).data.users).toEqual([]);
  });
});

describe("stats", () => {
  it("sums this week and fills empty weeks", async () => {
    const sam = await signUp("sam");
    await addActivity(sam.token, { durationSeconds: 1800, distanceMeters: 5000, activeEnergyKcal: 400 });
    await addActivity(sam.token, { type: "strength", durationSeconds: 3000, distanceMeters: null });
    await addActivity(sam.token, { startedAt: daysAgo(21), durationSeconds: 600, distanceMeters: 1000 });

    const { status, data } = await call(stats, { token: sam.token, query: { weeks: "8", tz: "Europe/Amsterdam" } });
    expect(status).toBe(200);
    expect(data.weekly).toHaveLength(8);
    expect(data.thisWeek).toEqual({
      durationSeconds: 4800,
      distanceMeters: 5000,
      activeEnergyKcal: 400,
      count: 2,
      goalMinutes: 150,
    });
    expect(data.weekly[7]).toMatchObject({ durationSeconds: 4800, count: 2 });
    expect(data.weekly[4]).toMatchObject({ durationSeconds: 600, count: 1 });
    expect(data.weekly[6]).toMatchObject({ durationSeconds: 0, count: 0 });
    // Weeks are consecutive Mondays.
    for (const week of data.weekly) expect(new Date(`${week.weekStart}T00:00:00Z`).getUTCDay()).toBe(1);
    expect(data.totals).toEqual({ count: 3, durationSeconds: 5400, distanceMeters: 6000 });
    expect(data.byType).toEqual([
      { type: "strength", count: 1, durationSeconds: 3000, distanceMeters: 0 },
      { type: "run", count: 2, durationSeconds: 2400, distanceMeters: 6000 },
    ]);
    expect(data.currentStreakWeeks).toBe(1);
  });

  it("falls back to the default zone for an unknown time zone", async () => {
    const sam = await signUp("sam");
    const { status, data } = await call(stats, { token: sam.token, query: { tz: "Mars/Olympus" } });
    expect(status).toBe(200);
    expect(data.weekly).toHaveLength(12);
  });

  it("counts streaks back from the current week", () => {
    expect(streakFromWeeks([], "2026-11-09")).toBe(0);
    expect(streakFromWeeks(["2026-11-09", "2026-11-02", "2026-10-26"], "2026-11-09")).toBe(3);
    // No activity yet this week: the streak of the previous weeks still stands.
    expect(streakFromWeeks(["2026-11-02", "2026-10-26"], "2026-11-09")).toBe(2);
    // A gap ends it.
    expect(streakFromWeeks(["2026-11-09", "2026-10-26"], "2026-11-09")).toBe(1);
    expect(streakFromWeeks(["2026-10-26"], "2026-11-09")).toBe(0);
  });
});

describe("leaderboard", () => {
  it("ranks me and my friends on this week, without private activities of others", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const alex = await signUp("alex");
    await signUp("stranger");
    await befriend(sam, kim);
    await befriend(sam, alex);

    await addActivity(sam.token, { durationSeconds: 1800, visibility: "private" });
    await addActivity(kim.token, { durationSeconds: 3600 });
    await addActivity(kim.token, { durationSeconds: 7200, visibility: "private" });
    await addActivity(kim.token, { durationSeconds: 9000, startedAt: daysAgo(14) });

    const { data } = await call(leaderboard, { token: sam.token, query: { metric: "duration" } });
    expect(data.entries.map((e: { user: { username: string }; value: number; rank: number; isMe: boolean }) => [e.user.username, e.value, e.rank, e.isMe])).toEqual([
      ["kim", 3600, 1, false],
      ["sam", 1800, 2, true],
      ["alex", 0, 3, false],
    ]);

    const byCount = await call(leaderboard, { token: sam.token, query: { metric: "count" } });
    expect(byCount.data.entries.map((e: { rank: number }) => e.rank)).toEqual([1, 1, 3]);
  });
});
