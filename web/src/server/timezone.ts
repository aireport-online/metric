import { DEFAULT_TIME_ZONE } from "@/lib/constants";

/** Returns `tz` if it is a real IANA zone, otherwise the default. Safe to pass to Postgres. */
export function resolveTimeZone(tz: string | null | undefined): string {
  if (!tz) return DEFAULT_TIME_ZONE;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return tz;
  } catch {
    return DEFAULT_TIME_ZONE;
  }
}
