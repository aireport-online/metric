import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { SESSION_COOKIE, TZ_COOKIE } from "@/lib/constants";
import { createSession, deleteSession, getUserForToken } from "./auth";
import type { UserRow } from "./db/schema";
import { resolveTimeZone } from "./timezone";

/** The logged-in user for this request, or null. Deduplicated per request. */
export const getSessionUser = cache(async (): Promise<UserRow | null> => {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  return getUserForToken(token);
});

export async function requireUser(): Promise<UserRow> {
  const user = await getSessionUser();
  if (!user) redirect("/login");
  return user;
}

export async function getTimeZone(): Promise<string> {
  return resolveTimeZone((await cookies()).get(TZ_COOKIE)?.value);
}

export async function startWebSession(userId: string) {
  const { token, expiresAt } = await createSession(userId, "web");
  (await cookies()).set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    expires: expiresAt,
  });
}

export async function endWebSession() {
  const jar = await cookies();
  await deleteSession(jar.get(SESSION_COOKIE)?.value);
  jar.delete(SESSION_COOKIE);
}
