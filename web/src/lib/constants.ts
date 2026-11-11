export const ACTIVITY_TYPES = [
  "run",
  "walk",
  "hike",
  "ride",
  "swim",
  "strength",
  "hiit",
  "yoga",
  "rowing",
  "football",
  "tennis",
  "other",
] as const;
export type ActivityType = (typeof ACTIVITY_TYPES)[number];

export const ACTIVITY_SOURCES = ["iphone", "watch", "health", "web"] as const;
export type ActivitySource = (typeof ACTIVITY_SOURCES)[number];

export const VISIBILITIES = ["private", "friends", "public"] as const;
export type Visibility = (typeof VISIBILITIES)[number];

export const DEFAULT_TIME_ZONE = "Europe/Amsterdam";
export const SESSION_COOKIE = "metric_session";
export const TZ_COOKIE = "metric_tz";
