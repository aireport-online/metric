import Link from "next/link";
import { WeekColumns } from "@/components/charts";
import { KudosIcon } from "@/components/icons";
import { Logo } from "@/components/logo";
import { RouteThumb } from "@/components/route-map";
import { Avatar, Figure, Panel } from "@/components/ui";
import { WeekGoal } from "@/components/week-goal";
import { SAMPLE_DAYS, SAMPLE_GOAL, SAMPLE_ROUTE, SAMPLE_WEEK_SECONDS, SAMPLE_WEEKS } from "@/lib/sample";

export default function StartPage() {
  return (
    <div className="column flex min-h-screen flex-col">
      <header className="flex h-12 flex-none items-center justify-between">
        <Logo />
        <Link href="/login" className="btn btn-secondary btn-sm">
          Inloggen
        </Link>
      </header>

      {/* 480 + 48 + 624 = 1152 */}
      <main className="grid flex-1 items-center gap-x-12 gap-y-10 py-10 lg:grid-cols-[480px_minmax(0,1fr)]">
        <div>
          <h1 className="text-[32px] font-bold leading-[1.15] tracking-[-0.02em] max-sm:text-[26px]">Sport bijhouden met je vrienden</h1>
          <p className="mt-4 max-w-[44ch] text-[16px] leading-6">
            Metric verzamelt je workouts van iPhone en Apple Watch, laat zien of je je weekdoel haalt en deelt je
            voortgang met de vrienden die jij kiest.
          </p>
          <div className="mt-6 flex flex-wrap gap-2">
            <Link href="/register" className="btn btn-primary">
              Account aanmaken
            </Link>
            <Link href="/login" className="btn btn-secondary">
              Inloggen
            </Link>
          </div>
        </div>

        {/* A fragment of the app itself, drawn with its own components from sample data. */}
        <div data-ui inert className="grid gap-3 sm:grid-cols-2" aria-label="Voorbeeld van de app">
          <Panel title="Deze week">
            <WeekGoal seconds={SAMPLE_WEEK_SECONDS} goalMinutes={SAMPLE_GOAL} days={SAMPLE_DAYS} />
          </Panel>
          <Panel title="Minuten per week">
            <WeekColumns weeks={SAMPLE_WEEKS} goalMinutes={SAMPLE_GOAL} height={170} table={false} />
          </Panel>
          <article className="panel p-5 sm:col-span-2">
            <div className="flex items-start gap-3">
              <Avatar username="sanne" name="Sanne" size={40} />
              <div className="min-w-0 flex-1">
                <p>
                  <span className="font-medium">Sanne</span> <span className="text-muted">liep hard</span>
                </p>
                <p className="text-[12px] leading-5 text-muted">Vandaag 07:12</p>
                <h2 className="mt-2 text-[16px] font-medium leading-6">Rondje Vondelpark voor het werk</h2>
              </div>
              <RouteThumb route={SAMPLE_ROUTE} />
            </div>
            <div className="mt-3 flex flex-wrap items-end justify-between gap-4 sm:pl-[52px]">
              <div className="flex flex-wrap gap-x-8 gap-y-2">
                <Figure label="Afstand" value="5,12" unit="km" />
                <Figure label="Duur" value="28:04" />
                <Figure label="Tempo" value="5:29" unit="/km" />
              </div>
              <span className="btn btn-sm btn-on">
                <KudosIcon />
                Kudos <span className="num">4</span>
              </span>
            </div>
          </article>
        </div>
      </main>
    </div>
  );
}
