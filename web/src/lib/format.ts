import { ACTIVITY_INFO } from "./activity-types";
import type { ActivityType } from "./constants";

const nl = (options: Intl.NumberFormatOptions) => new Intl.NumberFormat("nl-NL", options);
const one = nl({ minimumFractionDigits: 1, maximumFractionDigits: 1 });
const two = nl({ minimumFractionDigits: 2, maximumFractionDigits: 2 });
const whole = nl({ maximumFractionDigits: 0 });

export const formatCount = (value: number) => whole.format(value);

/** 1820 → "30:20", 5400 → "1:30:00" */
export function formatClock(seconds: number): string {
  const s = Math.round(seconds);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const rest = String(s % 60).padStart(2, "0");
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${rest}` : `${m}:${rest}`;
}

/** Total time in words: 5400 → "1 u 30 min", 1500 → "25 min". */
export function formatHoursMinutes(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} min`;
  return m === 0 ? `${whole.format(h)} u` : `${whole.format(h)} u ${m} min`;
}

export const toMinutes = (seconds: number) => Math.round(seconds / 60);

/** Kilometres with two decimals for one activity, one decimal for totals. */
export function formatKm(meters: number, decimals: 1 | 2 = 2): string {
  return (decimals === 2 ? two : one).format(meters / 1000);
}

/** Pace in min/km or speed in km/u, depending on the sport. Null when it does not apply. */
export function formatRate(
  type: ActivityType,
  distanceMeters: number | null,
  durationSeconds: number,
): { label: string; value: string; unit: string } | null {
  const rate = ACTIVITY_INFO[type].rate;
  if (rate === "none" || !distanceMeters || distanceMeters < 50 || durationSeconds <= 0) return null;
  if (rate === "pace") {
    const secondsPerKm = Math.round(durationSeconds / (distanceMeters / 1000));
    return {
      label: "Tempo",
      value: `${Math.floor(secondsPerKm / 60)}:${String(secondsPerKm % 60).padStart(2, "0")}`,
      unit: "/km",
    };
  }
  return { label: "Snelheid", value: one.format(distanceMeters / 1000 / (durationSeconds / 3600)), unit: "km/u" };
}

const dayKey = (date: Date, timeZone: string) =>
  new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(date);

/** "Vandaag 07:30", "Gisteren 18:05", "ma 9 nov 07:30", "12 mrt 2025". */
export function formatWhen(iso: string, timeZone: string, now = new Date()): string {
  const date = new Date(iso);
  const time = new Intl.DateTimeFormat("nl-NL", { timeZone, hour: "2-digit", minute: "2-digit" }).format(date);
  const key = dayKey(date, timeZone);
  if (key === dayKey(now, timeZone)) return `Vandaag ${time}`;
  if (key === dayKey(new Date(now.getTime() - 24 * 3600 * 1000), timeZone)) return `Gisteren ${time}`;
  const sameYear = key.slice(0, 4) === dayKey(now, timeZone).slice(0, 4);
  const day = new Intl.DateTimeFormat("nl-NL", {
    timeZone,
    weekday: sameYear ? "short" : undefined,
    day: "numeric",
    month: "short",
    year: sameYear ? undefined : "numeric",
  }).format(date);
  return sameYear ? `${day} ${time}` : day;
}

export function formatFullDate(iso: string, timeZone: string): string {
  return new Intl.DateTimeFormat("nl-NL", {
    timeZone,
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

/** "2026-11-09" → "9 nov" */
export function formatWeekStart(weekStart: string): string {
  return new Intl.DateTimeFormat("nl-NL", { timeZone: "UTC", day: "numeric", month: "short" }).format(
    new Date(`${weekStart}T00:00:00Z`),
  );
}

export function formatMonthYear(iso: string): string {
  return new Intl.DateTimeFormat("nl-NL", { month: "long", year: "numeric" }).format(new Date(iso));
}

/** Value for <input type="datetime-local"> in the viewer's zone. */
export function toLocalInputValue(date: Date, timeZone: string): string {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

/** Interprets "2026-11-11T07:30" as wall-clock time in `timeZone` and returns the instant. */
export function fromLocalInputValue(value: string, timeZone: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value);
  if (!match) return null;
  const [, y, mo, d, h, mi] = match.map(Number);
  const asUtc = Date.UTC(y, mo - 1, d, h, mi);
  // Offset of the zone at that moment; one correction pass handles DST edges.
  const offsetAt = (instant: number) => {
    const local = toLocalInputValue(new Date(instant), timeZone);
    const [ly, lmo, ld, lh, lmi] = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(local)!.slice(1).map(Number);
    return Date.UTC(ly, lmo - 1, ld, lh, lmi) - instant;
  };
  let instant = asUtc - offsetAt(asUtc);
  instant = asUtc - offsetAt(instant);
  return new Date(instant);
}

/** Stable pale tint per person, so the same friend always has the same colour. */
export function personHue(username: string): number {
  let hash = 0;
  for (const char of username) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return (hash % 6) * 60 + 20;
}

export const initialOf = (name: string) => (name.trim()[0] ?? "?").toUpperCase();
