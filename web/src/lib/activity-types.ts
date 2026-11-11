import type { ActivitySource, ActivityType, Visibility } from "./constants";

type TypeInfo = { label: string; verb: string; distance: boolean; rate: "pace" | "speed" | "none" };

export const ACTIVITY_INFO: Record<ActivityType, TypeInfo> = {
  run: { label: "Hardlopen", verb: "liep hard", distance: true, rate: "pace" },
  walk: { label: "Wandelen", verb: "wandelde", distance: true, rate: "pace" },
  hike: { label: "Hiken", verb: "maakte een hike", distance: true, rate: "pace" },
  ride: { label: "Fietsen", verb: "fietste", distance: true, rate: "speed" },
  swim: { label: "Zwemmen", verb: "zwom", distance: true, rate: "none" },
  strength: { label: "Krachttraining", verb: "deed krachttraining", distance: false, rate: "none" },
  hiit: { label: "HIIT", verb: "deed een HIIT-training", distance: false, rate: "none" },
  yoga: { label: "Yoga", verb: "deed yoga", distance: false, rate: "none" },
  rowing: { label: "Roeien", verb: "roeide", distance: true, rate: "speed" },
  football: { label: "Voetbal", verb: "voetbalde", distance: false, rate: "none" },
  tennis: { label: "Tennis", verb: "tenniste", distance: false, rate: "none" },
  other: { label: "Overig", verb: "sportte", distance: false, rate: "none" },
};

export const VISIBILITY_LABEL: Record<Visibility, string> = {
  private: "Alleen ik",
  friends: "Vrienden",
  public: "Iedereen met de link",
};

export const SOURCE_LABEL: Record<ActivitySource, string> = {
  iphone: "iPhone",
  watch: "Apple Watch",
  health: "Apple Gezondheid",
  web: "website",
};
