import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { POST as login } from "@/app/api/v1/auth/login/route";
import { POST as logout } from "@/app/api/v1/auth/logout/route";
import { POST as register } from "@/app/api/v1/auth/register/route";
import { DELETE as deleteMe, GET as me, PATCH as patchMe } from "@/app/api/v1/me/route";
import { GET as listActivities } from "@/app/api/v1/activities/route";
import { getPool } from "@/server/db";
import { addActivity, call, resetDb, signUp } from "./helpers";

beforeEach(resetDb);
afterAll(() => getPool().end());

describe("accounts", () => {
  it("registers, normalises the username and returns a working token", async () => {
    const { status, data } = await call(register, {
      body: { email: " Sam@Example.com ", password: "geheim-wachtwoord", username: "Sam_1", displayName: "Sam" },
    });
    expect(status).toBe(201);
    expect(data.user).toMatchObject({ username: "sam_1", email: "sam@example.com", weeklyGoalMinutes: 150 });
    expect(data.user.passwordHash).toBeUndefined();

    const current = await call(me, { token: data.token });
    expect(current.status).toBe(200);
    expect(current.data.user.username).toBe("sam_1");
  });

  it("rejects duplicate e-mail and username with distinct codes", async () => {
    await signUp("sam");
    const sameEmail = await call(register, {
      body: { email: "sam@example.com", password: "geheim-wachtwoord", username: "other", displayName: "x" },
    });
    expect(sameEmail.status).toBe(409);
    expect(sameEmail.data.error.code).toBe("email_taken");

    const sameName = await call(register, {
      body: { email: "new@example.com", password: "geheim-wachtwoord", username: "SAM", displayName: "x" },
    });
    expect(sameName.status).toBe(409);
    expect(sameName.data.error.code).toBe("username_taken");
  });

  it("validates input", async () => {
    const short = await call(register, {
      body: { email: "a@example.com", password: "kort", username: "abc", displayName: "x" },
    });
    expect(short.status).toBe(400);
    expect(short.data.error.code).toBe("invalid_request");

    const reserved = await call(register, {
      body: { email: "a@example.com", password: "geheim-wachtwoord", username: "search", displayName: "x" },
    });
    expect(reserved.status).toBe(400);
  });

  it("logs in with the right password only, and logout invalidates the token", async () => {
    await signUp("sam");
    const wrong = await call(login, { body: { email: "sam@example.com", password: "fout" } });
    expect(wrong.status).toBe(401);
    expect(wrong.data.error.code).toBe("invalid_credentials");
    const unknown = await call(login, { body: { email: "nobody@example.com", password: "geheim-wachtwoord" } });
    expect(unknown.status).toBe(401);

    const ok = await call(login, { body: { email: "SAM@example.com", password: "geheim-wachtwoord" } });
    expect(ok.status).toBe(200);

    expect((await call(logout, { method: "POST", token: ok.data.token })).status).toBe(204);
    expect((await call(me, { token: ok.data.token })).status).toBe(401);
  });

  it("requires authentication", async () => {
    expect((await call(me)).status).toBe(401);
    expect((await call(me, { token: "not-a-token" })).status).toBe(401);
    expect((await call(listActivities)).status).toBe(401);
  });

  it("updates profile settings", async () => {
    const sam = await signUp("sam");
    const { status, data } = await call(patchMe, {
      method: "PATCH",
      token: sam.token,
      body: { weeklyGoalMinutes: 240, defaultVisibility: "private", bio: "Hardloper" },
    });
    expect(status).toBe(200);
    expect(data.user).toMatchObject({ weeklyGoalMinutes: 240, defaultVisibility: "private", bio: "Hardloper" });

    const activity = await addActivity(sam.token);
    expect(activity.visibility).toBe("private");
  });

  it("deletes the account with all its data, but only with the password", async () => {
    const sam = await signUp("sam");
    await addActivity(sam.token);

    const wrong = await call(deleteMe, { method: "DELETE", token: sam.token, body: { password: "fout" } });
    expect(wrong.status).toBe(401);

    const ok = await call(deleteMe, { method: "DELETE", token: sam.token, body: { password: "geheim-wachtwoord" } });
    expect(ok.status).toBe(204);
    expect((await call(me, { token: sam.token })).status).toBe(401);
    const left = await getPool().query("select (select count(*) from activities)::int + (select count(*) from sessions)::int as n");
    expect(left.rows[0].n).toBe(0);
  });
});
