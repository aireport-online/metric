import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { DELETE as removeActivity, GET as getActivity, PATCH as patchActivity } from "@/app/api/v1/activities/[id]/route";
import { POST as comment } from "@/app/api/v1/activities/[id]/comments/route";
import { DELETE as unkudo, POST as kudo } from "@/app/api/v1/activities/[id]/kudos/route";
import { POST as batch } from "@/app/api/v1/activities/batch/route";
import { GET as listActivities, POST as createActivity } from "@/app/api/v1/activities/route";
import { DELETE as removeComment } from "@/app/api/v1/comments/[id]/route";
import { GET as feed } from "@/app/api/v1/feed/route";
import { GET as profile } from "@/app/api/v1/users/[username]/route";
import { getPool } from "@/server/db";
import { activityInput, addActivity, befriend, call, resetDb, signUp } from "./helpers";

beforeEach(resetDb);
afterAll(() => getPool().end());

const hoursAgo = (hours: number) => new Date(Date.now() - hours * 3600_000).toISOString();

describe("activities", () => {
  it("stores an activity and returns the route only in the detail response", async () => {
    const sam = await signUp("sam");
    const route = [
      [52.37, 4.89],
      [52.371, 4.891],
      [52.372, 4.893],
    ];
    const created = await call(createActivity, {
      token: sam.token,
      body: activityInput({ title: "Ochtendrun", avgHeartRate: 151.6, route, source: "watch" }),
    });
    expect(created.status).toBe(201);
    expect(created.data.activity).toMatchObject({
      title: "Ochtendrun",
      type: "run",
      avgHeartRate: 152,
      hasRoute: true,
      visibility: "friends",
      source: "watch",
      kudosCount: 0,
      user: { username: "sam" },
    });
    expect(created.data.activity.route).toBeUndefined();

    const list = await call(listActivities, { token: sam.token });
    expect(list.data.activities).toHaveLength(1);
    expect(list.data.activities[0].route).toBeUndefined();

    const detail = await call(getActivity, { token: sam.token, params: { id: created.data.activity.id } });
    expect(detail.data.activity.route).toEqual(route);
    expect(detail.data.comments).toEqual([]);
  });

  it("is idempotent per clientId and keeps website edits on re-sync", async () => {
    const sam = await signUp("sam");
    const input = activityInput({ durationSeconds: 1800 });
    const first = await call(createActivity, { token: sam.token, body: input });
    expect(first.status).toBe(201);

    await call(patchActivity, {
      method: "PATCH",
      token: sam.token,
      params: { id: first.data.activity.id },
      body: { title: "Aangepast op de site", visibility: "public" },
    });

    // The phone uploads the same workout again, now with a corrected duration and no title.
    const again = await call(createActivity, { token: sam.token, body: { ...input, durationSeconds: 1900 } });
    expect(again.status).toBe(200);
    expect(again.data.activity).toMatchObject({
      id: first.data.activity.id,
      durationSeconds: 1900,
      title: "Aangepast op de site",
      visibility: "public",
    });
    expect((await call(listActivities, { token: sam.token })).data.activities).toHaveLength(1);
  });

  it("keeps the same clientId separate per user", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const input = activityInput();
    expect((await call(createActivity, { token: sam.token, body: input })).status).toBe(201);
    expect((await call(createActivity, { token: kim.token, body: input })).status).toBe(201);
  });

  it("uploads a batch and pages through the list by cursor", async () => {
    const sam = await signUp("sam");
    const activities = [1, 2, 3, 4, 5].map((n) => activityInput({ startedAt: hoursAgo(n), title: `#${n}` }));
    const uploaded = await call(batch, { token: sam.token, body: { activities } });
    expect(uploaded.status).toBe(200);
    expect(uploaded.data.activities).toHaveLength(5);

    const page1 = await call(listActivities, { token: sam.token, query: { limit: "2" } });
    expect(page1.data.activities.map((a: { title: string }) => a.title)).toEqual(["#1", "#2"]);
    expect(page1.data.nextCursor).toBeTruthy();

    const page2 = await call(listActivities, { token: sam.token, query: { limit: "2", before: page1.data.nextCursor } });
    expect(page2.data.activities.map((a: { title: string }) => a.title)).toEqual(["#3", "#4"]);

    const page3 = await call(listActivities, { token: sam.token, query: { limit: "2", before: page2.data.nextCursor } });
    expect(page3.data.activities.map((a: { title: string }) => a.title)).toEqual(["#5"]);
    expect(page3.data.nextCursor).toBeNull();
  });

  it("rejects invalid input", async () => {
    const sam = await signUp("sam");
    for (const bad of [
      { type: "curling" },
      { durationSeconds: 0 },
      { clientId: "nope" },
      { startedAt: "gisteren" },
      { route: [[123, 4]] },
    ]) {
      const res = await call(createActivity, { token: sam.token, body: activityInput(bad) });
      expect(res.status, JSON.stringify(bad)).toBe(400);
    }
    expect((await call(getActivity, { token: sam.token, params: { id: "not-a-uuid" } })).status).toBe(404);
  });

  it("only lets the owner edit or delete", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const activity = await addActivity(sam.token, { visibility: "public" });
    const params = { id: activity.id };

    expect((await call(patchActivity, { method: "PATCH", token: kim.token, params, body: { title: "x" } })).status).toBe(404);
    expect((await call(removeActivity, { method: "DELETE", token: kim.token, params })).status).toBe(404);
    expect((await call(removeActivity, { method: "DELETE", token: sam.token, params })).status).toBe(204);
    expect((await call(getActivity, { token: sam.token, params })).status).toBe(404);
  });
});

describe("visibility", () => {
  it("shows private to nobody else, friends to friends, public to everyone", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim"); // friend
    const alex = await signUp("alex"); // stranger
    await befriend(sam, kim);

    const priv = await addActivity(sam.token, { visibility: "private" });
    const friends = await addActivity(sam.token, { visibility: "friends" });
    const pub = await addActivity(sam.token, { visibility: "public" });

    const status = async (token: string | null, id: string) => (await call(getActivity, { token, params: { id } })).status;

    expect(await status(sam.token, priv.id)).toBe(200);
    expect(await status(kim.token, priv.id)).toBe(404);
    expect(await status(alex.token, priv.id)).toBe(404);

    expect(await status(kim.token, friends.id)).toBe(200);
    expect(await status(alex.token, friends.id)).toBe(404);
    expect(await status(null, friends.id)).toBe(404);

    expect(await status(alex.token, pub.id)).toBe(200);
    expect(await status(null, pub.id)).toBe(200);
  });

  it("applies the same rules to the feed and to profiles", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const alex = await signUp("alex");
    await befriend(sam, kim);

    await addActivity(sam.token, { visibility: "private", title: "private" });
    await addActivity(sam.token, { visibility: "friends", title: "friends" });
    await addActivity(sam.token, { visibility: "public", title: "public" });
    await addActivity(alex.token, { visibility: "public", title: "stranger" });

    const titles = (data: { activities: { title: string }[] }) => data.activities.map((a) => a.title).sort();

    expect(titles((await call(feed, { token: sam.token })).data)).toEqual(["friends", "private", "public"]);
    // Kim sees what Sam shares with friends, not Sam's private run and not a stranger's public one.
    expect(titles((await call(feed, { token: kim.token })).data)).toEqual(["friends", "public"]);
    expect(titles((await call(feed, { token: alex.token })).data)).toEqual(["stranger"]);

    const view = async (token: string | null) => (await call(profile, { token, params: { username: "sam" } })).data;
    expect((await view(sam.token)).relation).toBe("self");
    expect(titles(await view(sam.token))).toEqual(["friends", "private", "public"]);
    expect((await view(kim.token)).relation).toBe("friends");
    expect(titles(await view(kim.token))).toEqual(["friends", "public"]);
    expect(titles(await view(alex.token))).toEqual(["public"]);
    const anonymous = await view(null);
    expect(titles(anonymous)).toEqual(["public"]);
    expect(anonymous.stats.count).toBe(1);
    expect(anonymous.user.email).toBeUndefined();
  });
});

describe("kudos and comments", () => {
  it("toggles kudos once per user", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    await befriend(sam, kim);
    const activity = await addActivity(sam.token);
    const params = { id: activity.id };

    expect((await call(kudo, { method: "POST", token: kim.token, params })).data).toEqual({ kudosCount: 1, hasKudoed: true });
    expect((await call(kudo, { method: "POST", token: kim.token, params })).data).toEqual({ kudosCount: 1, hasKudoed: true });
    expect((await call(kudo, { method: "POST", token: sam.token, params })).data.kudosCount).toBe(2);

    const seenByKim = await call(getActivity, { token: kim.token, params });
    expect(seenByKim.data.activity).toMatchObject({ kudosCount: 2, hasKudoed: true });

    expect((await call(unkudo, { method: "DELETE", token: kim.token, params })).data).toEqual({ kudosCount: 1, hasKudoed: false });
  });

  it("refuses kudos and comments on activities you cannot see", async () => {
    const sam = await signUp("sam");
    const alex = await signUp("alex");
    const activity = await addActivity(sam.token, { visibility: "friends" });
    const params = { id: activity.id };
    expect((await call(kudo, { method: "POST", token: alex.token, params })).status).toBe(404);
    expect((await call(comment, { token: alex.token, params, body: { body: "hoi" } })).status).toBe(404);
  });

  it("lets the author or the activity owner delete a comment", async () => {
    const sam = await signUp("sam");
    const kim = await signUp("kim");
    const alex = await signUp("alex");
    const activity = await addActivity(sam.token, { visibility: "public" });
    const params = { id: activity.id };

    const byKim = await call(comment, { token: kim.token, params, body: { body: "  Lekker bezig!  " } });
    expect(byKim.status).toBe(201);
    expect(byKim.data.comment).toMatchObject({ body: "Lekker bezig!", user: { username: "kim" } });
    const byAlex = await call(comment, { token: alex.token, params, body: { body: "Top" } });

    const detail = await call(getActivity, { token: sam.token, params });
    expect(detail.data.comments.map((c: { body: string }) => c.body)).toEqual(["Lekker bezig!", "Top"]);
    expect(detail.data.activity.commentCount).toBe(2);

    // Alex may not remove Kim's comment; Kim (author) and Sam (owner) may.
    expect((await call(removeComment, { method: "DELETE", token: alex.token, params: { id: byKim.data.comment.id } })).status).toBe(404);
    expect((await call(removeComment, { method: "DELETE", token: kim.token, params: { id: byKim.data.comment.id } })).status).toBe(204);
    expect((await call(removeComment, { method: "DELETE", token: sam.token, params: { id: byAlex.data.comment.id } })).status).toBe(204);
    expect((await call(comment, { token: kim.token, params, body: { body: "   " } })).status).toBe(400);
  });
});
