import { createHash, randomBytes, scrypt, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { and, eq, gt, lt } from "drizzle-orm";
import type { z } from "zod";
import type { loginSchema, registerSchema, updateMeSchema } from "@/lib/schemas";
import { getDb } from "./db";
import { sessions, users, type UserRow } from "./db/schema";
import { ApiError, isUniqueViolation } from "./errors";

const scryptAsync = promisify(scrypt) as (password: string, salt: Buffer, keylen: number) => Promise<Buffer>;

const KEY_LENGTH = 64;
const SESSION_DAYS: Record<"web" | "app", number> = { web: 60, app: 365 };
const DAY_MS = 24 * 3600 * 1000;

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await scryptAsync(password, salt, KEY_LENGTH);
  return `scrypt$${salt.toString("base64")}$${key.toString("base64")}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, saltB64, keyB64] = stored.split("$");
  if (scheme !== "scrypt" || !saltB64 || !keyB64) return false;
  const expected = Buffer.from(keyB64, "base64");
  const actual = await scryptAsync(password, Buffer.from(saltB64, "base64"), expected.length);
  return timingSafeEqual(actual, expected);
}

// Compared against when the e-mail address is unknown, so both paths take equally long.
let dummyHash: Promise<string> | undefined;

function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export async function createSession(userId: string, kind: "web" | "app") {
  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + SESSION_DAYS[kind] * DAY_MS);
  await getDb().insert(sessions).values({ tokenHash: hashToken(token), userId, kind, expiresAt });
  return { token, expiresAt };
}

export async function getUserForToken(token: string | null | undefined): Promise<UserRow | null> {
  if (!token) return null;
  const db = getDb();
  const [row] = await db
    .select({ user: users, session: sessions })
    .from(sessions)
    .innerJoin(users, eq(users.id, sessions.userId))
    .where(and(eq(sessions.tokenHash, hashToken(token)), gt(sessions.expiresAt, new Date())))
    .limit(1);
  if (!row) return null;

  // Sliding expiry, written at most once a day per session.
  if (Date.now() - row.session.lastUsedAt.getTime() > DAY_MS) {
    const now = new Date();
    await db
      .update(sessions)
      .set({ lastUsedAt: now, expiresAt: new Date(now.getTime() + SESSION_DAYS[row.session.kind] * DAY_MS) })
      .where(eq(sessions.id, row.session.id));
  }
  return row.user;
}

export async function deleteSession(token: string | null | undefined) {
  if (!token) return;
  await getDb().delete(sessions).where(eq(sessions.tokenHash, hashToken(token)));
}

export async function deleteExpiredSessions() {
  await getDb().delete(sessions).where(lt(sessions.expiresAt, new Date()));
}

export async function registerUser(input: z.infer<typeof registerSchema>): Promise<UserRow> {
  const passwordHash = await hashPassword(input.password);
  try {
    const [user] = await getDb()
      .insert(users)
      .values({
        email: input.email,
        username: input.username,
        displayName: input.displayName,
        passwordHash,
      })
      .returning();
    return user;
  } catch (error) {
    if (isUniqueViolation(error, "users_email_unique")) {
      throw new ApiError(409, "email_taken", "Er bestaat al een account met dit e-mailadres.");
    }
    if (isUniqueViolation(error, "users_username_unique")) {
      throw new ApiError(409, "username_taken", "Deze gebruikersnaam is al bezet.");
    }
    throw error;
  }
}

export async function authenticate(input: z.infer<typeof loginSchema>): Promise<UserRow> {
  const [user] = await getDb().select().from(users).where(eq(users.email, input.email)).limit(1);
  dummyHash ??= hashPassword("not-a-real-password");
  const ok = await verifyPassword(input.password, user?.passwordHash ?? (await dummyHash));
  if (!user || !ok) {
    throw new ApiError(401, "invalid_credentials", "E-mailadres of wachtwoord klopt niet.");
  }
  return user;
}

export async function updateUser(userId: string, patch: z.infer<typeof updateMeSchema>): Promise<UserRow> {
  const db = getDb();
  if (Object.keys(patch).length === 0) {
    const [user] = await db.select().from(users).where(eq(users.id, userId));
    return user;
  }
  const [user] = await db.update(users).set(patch).where(eq(users.id, userId)).returning();
  return user;
}

/** Deletes the account and, through foreign keys, everything that belongs to it. */
export async function deleteUser(user: UserRow, password: string) {
  if (!(await verifyPassword(password, user.passwordHash))) {
    throw new ApiError(401, "invalid_credentials", "Het wachtwoord klopt niet.");
  }
  await getDb().delete(users).where(eq(users.id, user.id));
}
