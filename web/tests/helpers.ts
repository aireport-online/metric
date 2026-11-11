import { randomUUID } from "node:crypto";
import { NextRequest } from "next/server";
import { POST as register } from "@/app/api/v1/auth/register/route";
import { POST as createActivity } from "@/app/api/v1/activities/route";
import { POST as requestFriend } from "@/app/api/v1/friends/requests/route";
import { getPool } from "@/server/db";

type RouteHandler = (req: NextRequest, args: { params: Promise<Record<string, string>> }) => Promise<Response>;

export async function call(
  handler: RouteHandler,
  options: {
    method?: string;
    token?: string | null;
    body?: unknown;
    params?: Record<string, string>;
    query?: Record<string, string>;
  } = {},
) {
  const url = new URL("http://test.local/api/v1/x");
  for (const [key, value] of Object.entries(options.query ?? {})) url.searchParams.set(key, value);
  const req = new NextRequest(url, {
    method: options.method ?? (options.body === undefined ? "GET" : "POST"),
    headers: {
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...(options.body === undefined ? {} : { "content-type": "application/json" }),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const res = await handler(req, { params: Promise.resolve(options.params ?? {}) });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data: any = res.status === 204 ? null : await res.json();
  return { status: res.status, data };
}

export async function resetDb() {
  await getPool().query("truncate users, sessions, activities, friendships, kudos, comments cascade");
}

export async function signUp(username: string) {
  const { status, data } = await call(register, {
    body: { email: `${username}@example.com`, password: "geheim-wachtwoord", username, displayName: username },
  });
  if (status !== 201) throw new Error(`register failed: ${JSON.stringify(data)}`);
  return { token: data.token as string, user: data.user as { id: string; username: string } };
}

export function activityInput(overrides: Record<string, unknown> = {}) {
  return {
    clientId: randomUUID(),
    type: "run",
    startedAt: new Date().toISOString(),
    durationSeconds: 1800,
    distanceMeters: 5000,
    source: "iphone",
    ...overrides,
  };
}

export async function addActivity(token: string, overrides: Record<string, unknown> = {}) {
  const { status, data } = await call(createActivity, { token, body: activityInput(overrides) });
  if (status !== 201 && status !== 200) throw new Error(`create failed: ${JSON.stringify(data)}`);
  return data.activity as { id: string; clientId: string; visibility: string; title: string };
}

/** Makes two users friends: a invites b, b invites a back. */
export async function befriend(a: { token: string; user: { username: string } }, b: typeof a) {
  await call(requestFriend, { token: a.token, body: { username: b.user.username } });
  const { data } = await call(requestFriend, { token: b.token, body: { username: a.user.username } });
  if (data.status !== "friends") throw new Error("befriend failed");
}
