import Link from "next/link";
import { KudosIcon, SportIcon } from "@/components/icons";
import { LeaderboardList } from "@/components/leaderboard";
import { Logo } from "@/components/logo";
import { RouteThumb } from "@/components/route-map";
import { Figure, Panel } from "@/components/ui";
import { WeekGoal } from "@/components/week-goal";
import { ACTIVITY_INFO } from "@/lib/activity-types";
import { ACTIVITY_TYPES } from "@/lib/constants";
import { SAMPLE_BOARD, SAMPLE_DAYS, SAMPLE_GOAL, SAMPLE_ROUTE, SAMPLE_WEEK_SECONDS } from "@/lib/sample";

export default function StartPage() {
  return (
    <div className="column flex min-h-screen flex-col">
      <header className="flex h-16 flex-none items-center justify-between">
        <Logo />
        <Link href="/login" className="btn btn-secondary btn-sm">
          Inloggen
        </Link>
      </header>

      <main className="grid flex-1 grid-cols-[minmax(0,1fr)] items-center gap-x-14 gap-y-12 py-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,600px)]">
        <div className="stagger">
          <h1 className="figure-xl text-[clamp(64px,9vw,120px)]">
            Elke week
            <br />
            een ronde.
          </h1>
          <p className="mt-7 max-w-[46ch] text-[18px] leading-7 text-muted">
            <span className="text-ink">Metric houdt je sport bij.</span> Workouts van iPhone en Apple Watch komen vanzelf binnen, je ziet
            of je je weekdoel haalt en je deelt je voortgang met de vrienden die jij kiest.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/register" className="btn btn-primary">
              Account aanmaken
            </Link>
            <Link href="/login" className="btn btn-secondary">
              Inloggen
            </Link>
          </div>
          <ul className="mt-10 flex max-w-[520px] flex-wrap gap-x-5 gap-y-2.5 text-[15px] text-muted" aria-label="Sporten die Metric bijhoudt">
            {ACTIVITY_TYPES.filter((type) => type !== "other").map((type) => (
              <li key={type} className="flex items-center gap-2">
                <SportIcon type={type} size={18} />
                {ACTIVITY_INFO[type].label}
              </li>
            ))}
          </ul>
        </div>

        {/* A fragment of the app itself, drawn with its own components from sample data. */}
        <div data-ui inert className="stagger flex flex-col gap-4" aria-label="Voorbeeld van de app">
          <Panel title="Deze week">
            <div className="pt-2">
              <WeekGoal seconds={SAMPLE_WEEK_SECONDS} goalMinutes={SAMPLE_GOAL} days={SAMPLE_DAYS} large sentence={false} />
            </div>
          </Panel>
          <div className="grid gap-4 sm:grid-cols-2">
            <Panel title="Startopstelling">
              <LeaderboardList board={SAMPLE_BOARD} />
            </Panel>
            <article className="panel relative overflow-hidden p-6 pl-7">
              <span aria-hidden className="absolute inset-y-0 left-0 w-[5px] bg-accent" />
              <div className="flex items-start gap-3">
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">Sanne</p>
                  <p className="flex items-center gap-1.5 text-[14px] leading-5 text-muted">
                    <SportIcon type="run" size={16} />
                    Vandaag 07:12
                  </p>
                </div>
                <RouteThumb route={SAMPLE_ROUTE} />
              </div>
              <h2 className="display mt-4 text-[24px] leading-[1.1]">Rondje Vondelpark</h2>
              <div className="mt-4 flex flex-wrap gap-x-7 gap-y-3">
                <Figure label="Afstand" value="5,12" unit="km" />
                <Figure label="Tempo" value="5:29" unit="/km" />
              </div>
              <span className="btn btn-sm btn-on mt-5">
                <KudosIcon />
                Kudos <span className="num">4</span>
              </span>
            </article>
          </div>
        </div>
      </main>
    </div>
  );
}
