import { z } from "zod";
import { ACTIVITY_SOURCES, ACTIVITY_TYPES, VISIBILITIES } from "./constants";

const isoDate = z.iso.datetime({ offset: true }).transform((value) => new Date(value));

// Names that would collide with routes or look official.
const RESERVED_USERNAMES = new Set(["search", "me", "admin", "api", "metric", "support", "help", "settings"]);

export const usernameSchema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9_]{3,20}$/, "Gebruikersnaam: 3–20 tekens, alleen letters, cijfers en _.")
  .refine((value) => !RESERVED_USERNAMES.has(value), "Deze gebruikersnaam is niet beschikbaar.");

export const registerSchema = z.object({
  email: z.string().trim().toLowerCase().pipe(z.email("Vul een geldig e-mailadres in.")),
  password: z.string().min(8, "Wachtwoord moet minimaal 8 tekens zijn.").max(200),
  username: usernameSchema,
  displayName: z.string().trim().min(1, "Vul je naam in.").max(50),
});

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().min(1, "Vul je e-mailadres in."),
  password: z.string().min(1, "Vul je wachtwoord in.").max(200),
});

export const updateMeSchema = z
  .object({
    displayName: z.string().trim().min(1).max(50),
    bio: z.string().trim().max(280),
    weeklyGoalMinutes: z.number().int().min(10).max(3000),
    defaultVisibility: z.enum(VISIBILITIES),
  })
  .partial();

export const deleteMeSchema = z.object({ password: z.string().min(1).max(200) });

const coordinate = z.tuple([z.number().min(-90).max(90), z.number().min(-180).max(180)]);

export const activityInputSchema = z.object({
  clientId: z.guid(),
  type: z.enum(ACTIVITY_TYPES),
  title: z.string().trim().max(80).optional(),
  notes: z.string().trim().max(2000).optional(),
  startedAt: isoDate,
  durationSeconds: z
    .number()
    .min(1)
    .max(7 * 24 * 3600)
    .transform(Math.round),
  distanceMeters: z.number().min(0).max(2_000_000).nullish(),
  elevationGainMeters: z.number().min(0).max(30_000).nullish(),
  activeEnergyKcal: z.number().min(0).max(50_000).nullish(),
  avgHeartRate: z.number().min(20).max(260).transform(Math.round).nullish(),
  maxHeartRate: z.number().min(20).max(260).transform(Math.round).nullish(),
  source: z.enum(ACTIVITY_SOURCES).default("iphone"),
  visibility: z.enum(VISIBILITIES).optional(),
  route: z.array(coordinate).max(1000).nullish(),
});
export type ActivityInput = z.infer<typeof activityInputSchema>;

export const activityBatchSchema = z.object({
  activities: z.array(activityInputSchema).min(1).max(50),
});

export const activityPatchSchema = z
  .object({
    title: z.string().trim().max(80),
    notes: z.string().trim().max(2000),
    visibility: z.enum(VISIBILITIES),
    type: z.enum(ACTIVITY_TYPES),
  })
  .partial();

export const commentSchema = z.object({
  body: z.string().trim().min(1, "Schrijf eerst een reactie.").max(500),
});

export const friendRequestSchema = z.object({ username: z.string().trim().toLowerCase().min(1).max(20) });

export const pageQuerySchema = (maxLimit: number, defaultLimit: number) =>
  z.object({
    before: isoDate.optional(),
    limit: z.coerce.number().int().min(1).max(maxLimit).default(defaultLimit),
  });

export const statsQuerySchema = z.object({
  weeks: z.coerce.number().int().min(1).max(52).default(12),
  tz: z.string().max(64).optional(),
});

export const leaderboardQuerySchema = z.object({
  metric: z.enum(["duration", "distance", "count"]).default("duration"),
  tz: z.string().max(64).optional(),
});
