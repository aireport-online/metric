import type { ActivityType } from "./constants";

/** Sport families of the house style; each has one fixed tint (see globals.css). */
export type SportFamily = "lopen" | "fietsen" | "water" | "kracht" | "veld" | "balans" | "overig";

export const SPORT_FAMILY: Record<ActivityType, SportFamily> = {
  run: "lopen",
  walk: "lopen",
  hike: "lopen",
  ride: "fietsen",
  swim: "water",
  rowing: "water",
  strength: "kracht",
  hiit: "kracht",
  football: "veld",
  tennis: "veld",
  yoga: "balans",
  other: "overig",
};

/** The tint of a sport as a CSS colour. Thin marks only, and always next to the icon and the name. */
export const sportColor = (type: ActivityType) => `var(--sport-${SPORT_FAMILY[type]})`;
