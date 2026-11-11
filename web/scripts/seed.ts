/**
 * Fills the database with demo people and about twelve weeks of activities, so every screen has
 * something to show. Safe to run again: it removes the demo accounts first.
 *
 *   npm run db:seed      → log in as sanne@example.com / metric-demo
 */
import { config } from "dotenv";
import { inArray } from "drizzle-orm";

config({ path: ".env.local", quiet: true });

import type { ActivitySource, ActivityType, Visibility } from "@/lib/constants";
import { fromLocalInputValue } from "@/lib/format";
import { addComment, setKudos, upsertActivity } from "@/server/activities";
import { registerUser, updateUser } from "@/server/auth";
import { getDb, getPool } from "@/server/db";
import { users, type UserRow } from "@/server/db/schema";
import { sendFriendRequest } from "@/server/friends";

const PASSWORD = "metric-demo";
const ZONE = "Europe/Amsterdam";
const WEEKS = 12;

// Deterministic, so two runs give the same people doing the same things.
let state = 20261111;
function random() {
  state |= 0;
  state = (state + 0x6d2b79f5) | 0;
  let t = Math.imul(state ^ (state >>> 15), 1 | state);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const between = (min: number, max: number) => min + random() * (max - min);
const pick = <T>(items: readonly T[]): T => items[Math.floor(random() * items.length)];
const uuid = () =>
  "xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx".replace(/x/g, () => Math.floor(random() * 16).toString(16));

type Habit = { weekday: number; type: ActivityType; hour: number; skip: number };
type Person = {
  username: string;
  displayName: string;
  bio: string;
  goal: number;
  home: [number, number];
  habits: Habit[];
};

const PEOPLE: Person[] = [
  {
    username: "sanne",
    displayName: "Sanne de Vries",
    bio: "Loopt het liefst vóór het werk. Traint voor de halve marathon van Amsterdam.",
    goal: 180,
    home: [52.358, 4.8686],
    habits: [
      { weekday: 1, type: "run", hour: 7, skip: 0.15 },
      { weekday: 2, type: "strength", hour: 18, skip: 0.3 },
      { weekday: 3, type: "run", hour: 7, skip: 0.2 },
      { weekday: 6, type: "run", hour: 9, skip: 0.1 },
    ],
  },
  {
    username: "daan",
    displayName: "Daan Bakker",
    bio: "Racefiets in het weekend, hardlopen als het regent.",
    goal: 240,
    home: [52.0907, 5.1214],
    habits: [
      { weekday: 2, type: "run", hour: 18, skip: 0.35 },
      { weekday: 5, type: "ride", hour: 9, skip: 0.15 },
      { weekday: 6, type: "ride", hour: 10, skip: 0.5 },
    ],
  },
  {
    username: "noor",
    displayName: "Noor Jansen",
    bio: "Yoga, zwemmen en lange wandelingen.",
    goal: 150,
    home: [51.934, 4.513],
    habits: [
      { weekday: 0, type: "yoga", hour: 19, skip: 0.2 },
      { weekday: 2, type: "swim", hour: 7, skip: 0.3 },
      { weekday: 4, type: "yoga", hour: 17, skip: 0.4 },
      { weekday: 6, type: "walk", hour: 11, skip: 0.25 },
    ],
  },
  {
    username: "lars",
    displayName: "Lars Visser",
    bio: "",
    goal: 120,
    home: [52.3874, 4.6462],
    habits: [
      { weekday: 3, type: "football", hour: 20, skip: 0.2 },
      { weekday: 5, type: "hiit", hour: 10, skip: 0.5 },
    ],
  },
  {
    username: "emma",
    displayName: "Emma Smit",
    bio: "Net begonnen met hardlopen.",
    goal: 90,
    home: [52.2215, 6.8937],
    habits: [
      { weekday: 1, type: "run", hour: 19, skip: 0.4 },
      { weekday: 5, type: "walk", hour: 14, skip: 0.4 },
    ],
  },
  {
    username: "tim",
    displayName: "Tim Mulder",
    bio: "",
    goal: 150,
    home: [51.4416, 5.4697],
    habits: [{ weekday: 6, type: "hike", hour: 9, skip: 0.6 }],
  },
];

const TITLES: Partial<Record<ActivityType, string[]>> = {
  run: ["Ochtendrun", "Rondje park", "Duurloop", "Intervallen 6 × 800 m", "Herstelloopje", ""],
  ride: ["Rondje Utrechtse Heuvelrug", "Koffierit", "Tegenwind heen, tegenwind terug", ""],
  walk: ["Wandeling langs de plas", "Ommetje", ""],
  hike: ["Dagtocht over de heide"],
  swim: ["Baantjes voor het werk", ""],
  strength: ["Benen en core", "Bovenlichaam", ""],
  yoga: ["Yin yoga", "Vinyasa", ""],
  hiit: ["Bootcamp in het park"],
  football: ["Training met het team", "Zaalvoetbal"],
};

const COMMENTS = ["Lekker bezig!", "Sterk tempo.", "Volgende keer ga ik mee.", "Mooi rondje.", "Zo, vroeg uit de veren!", "Topper."];

/** A wobbly loop around `home` whose length is about `meters`, as [lat, lon]. */
function loop(home: [number, number], meters: number): [number, number][] {
  const points = 140;
  const lobes = Math.floor(between(2, 5));
  const phase = between(0, Math.PI * 2);
  const wobble = between(0.12, 0.3);
  const shape = (t: number) => 1 + wobble * Math.sin(lobes * t + phase) + 0.08 * Math.cos(7 * t);
  // The wobble makes the path longer than a circle of the same radius; measure and rescale.
  const unit = Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * Math.PI * 2;
    return [shape(t) * Math.cos(t), shape(t) * Math.sin(t)];
  });
  let length = 0;
  for (let i = 1; i < unit.length; i++) length += Math.hypot(unit[i][0] - unit[i - 1][0], unit[i][1] - unit[i - 1][1]);
  const radius = meters / length;
  const offset = [between(-600, 600), between(-600, 600)];
  const cosLat = Math.cos((home[0] * Math.PI) / 180);
  return unit.map(([x, y]) => [
    Number((home[0] + (offset[1] + (y - unit[0][1]) * radius) / 111_320).toFixed(6)),
    Number((home[1] + (offset[0] + (x - unit[0][0]) * radius) / (111_320 * cosLat)).toFixed(6)),
  ]);
}

function workout(person: Person, type: ActivityType) {
  const round = (value: number) => Math.round(value);
  switch (type) {
    case "run": {
      const km = between(4, 12);
      return { km, seconds: round(km * between(310, 370)), hr: round(between(145, 166)), kcalPerMin: 11, route: true };
    }
    case "ride": {
      const km = between(28, 72);
      return { km, seconds: round((km / between(24, 30)) * 3600), hr: round(between(128, 150)), kcalPerMin: 9.5, route: true };
    }
    case "walk": {
      const km = between(3, 8);
      return { km, seconds: round(km * between(620, 720)), hr: round(between(95, 112)), kcalPerMin: 4.5, route: true };
    }
    case "hike": {
      const km = between(9, 17);
      return { km, seconds: round(km * between(700, 820)), hr: round(between(105, 125)), kcalPerMin: 6, route: true };
    }
    case "swim": {
      const km = between(1, 2.2);
      return { km, seconds: round(km * 10 * between(125, 145)), hr: round(between(125, 142)), kcalPerMin: 8.5, route: false };
    }
    default:
      return {
        km: null,
        seconds: round(between(35, 75) * 60),
        hr: round(between(110, 150)),
        kcalPerMin: type === "yoga" ? 3.5 : 8,
        route: false,
      };
  }
}

async function main() {
  if (process.env.NODE_ENV === "production") {
    throw new Error("Refusing to seed demo data with NODE_ENV=production.");
  }
  const db = getDb();
  await db.delete(users).where(
    inArray(
      users.username,
      PEOPLE.map((person) => person.username),
    ),
  );

  const accounts = new Map<string, UserRow>();
  for (const person of PEOPLE) {
    const user = await registerUser({
      email: `${person.username}@example.com`,
      password: PASSWORD,
      username: person.username,
      displayName: person.displayName,
    });
    accounts.set(person.username, await updateUser(user.id, { bio: person.bio, weeklyGoalMinutes: person.goal }));
  }
  const account = (username: string) => accounts.get(username)!;

  // Friendships: asking back accepts. Emma has asked Sanne; Sanne has asked Tim.
  for (const [a, b] of [["sanne", "daan"], ["sanne", "noor"], ["sanne", "lars"], ["daan", "noor"]]) {
    await sendFriendRequest(account(a), b);
    await sendFriendRequest(account(b), a);
  }
  await sendFriendRequest(account("emma"), "sanne");
  await sendFriendRequest(account("sanne"), "tim");
  const friendsOf: Record<string, string[]> = {
    sanne: ["daan", "noor", "lars"],
    daan: ["sanne", "noor"],
    noor: ["sanne", "daan"],
    lars: ["sanne"],
    emma: [],
    tim: [],
  };

  const now = new Date();
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: ZONE }).format(now); // YYYY-MM-DD
  const todayUtc = new Date(`${today}T00:00:00Z`);
  const mondayOffset = (todayUtc.getUTCDay() + 6) % 7;
  let count = 0;

  for (const person of PEOPLE) {
    const user = account(person.username);
    for (let week = WEEKS - 1; week >= 0; week--) {
      for (const habit of person.habits) {
        if (random() < habit.skip) continue;
        const day = new Date(todayUtc.getTime() - (mondayOffset + week * 7 - habit.weekday) * 24 * 3600 * 1000);
        const minute = String(Math.floor(between(0, 50))).padStart(2, "0");
        const startedAt = fromLocalInputValue(
          `${day.toISOString().slice(0, 10)}T${String(habit.hour).padStart(2, "0")}:${minute}`,
          ZONE,
        )!;
        const plan = workout(person, habit.type);
        if (startedAt.getTime() + plan.seconds * 1000 > now.getTime()) continue;

        const meters = plan.km === null ? null : Math.round(plan.km * 1000);
        const hasRoute = plan.route && meters !== null && random() < 0.8;
        const source: ActivitySource = hasRoute ? pick(["watch", "watch", "iphone"]) : pick(["watch", "health", "web"]);
        const visibility: Visibility = random() < 0.12 ? "private" : random() < 0.3 ? "public" : "friends";
        const { activity } = await upsertActivity(user, {
          clientId: uuid(),
          type: habit.type,
          title: pick(TITLES[habit.type] ?? [""]),
          notes: random() < 0.15 ? "Voelde goed, benen waren fris na de rustdag." : "",
          startedAt,
          durationSeconds: plan.seconds,
          distanceMeters: meters,
          elevationGainMeters: hasRoute ? Math.round(between(8, habit.type === "ride" ? 320 : 70)) : null,
          activeEnergyKcal: source === "web" ? null : Math.round((plan.seconds / 60) * plan.kcalPerMin),
          avgHeartRate: source === "web" ? null : plan.hr,
          maxHeartRate: source === "web" ? null : plan.hr + Math.round(between(12, 26)),
          source,
          visibility,
          route: hasRoute ? loop(person.home, meters!) : null,
        });
        count += 1;

        if (visibility === "private") continue;
        const recent = week < 3;
        for (const friend of friendsOf[person.username]) {
          if (random() < (recent ? 0.7 : 0.35)) await setKudos(account(friend).id, activity.id, true);
          if (recent && random() < 0.18) await addComment(account(friend), activity.id, pick(COMMENTS));
        }
      }
    }
  }

  await getPool().end();
  console.log(`Seeded ${PEOPLE.length} people and ${count} activities.`);
  console.log(`Log in as sanne@example.com (or daan, noor, lars, emma, tim) with password "${PASSWORD}".`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
