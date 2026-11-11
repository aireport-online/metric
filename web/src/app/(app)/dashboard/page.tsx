import type { Metadata } from "next";
import Link from "next/link";
import { SportList, WeekColumns } from "@/components/charts";
import { CountUp } from "@/components/count-up";
import { PlusIcon } from "@/components/icons";
import { Empty, Figure, PageTitle, Panel } from "@/components/ui";
import { goalSentence, WeekGoal } from "@/components/week-goal";
import { formatCount, formatHoursMinutes, formatMonthYear, toMinutes } from "@/lib/format";
import { getTimeZone, requireUser } from "@/server/session";
import { getStats, getWeekDays } from "@/server/stats";

export const metadata: Metadata = { title: "Voortgang" };

const WEEKS = 12;

export default async function DashboardPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  const [stats, days] = await Promise.all([getStats(user, WEEKS, timeZone), getWeekDays(user.id, timeZone)]);
  const { thisWeek, totals } = stats;
  // The foot of "Per sport" is the sum of the rows above it.
  const periodSeconds = stats.byType.reduce((sum, sport) => sum + sport.durationSeconds, 0);
  const periodCount = stats.byType.reduce((sum, sport) => sum + sport.count, 0);
  const weeksOnGoal = stats.weekly.filter((week) => toMinutes(week.durationSeconds) >= thisWeek.goalMinutes).length;
  const streak = stats.currentStreakWeeks;

  return (
    <>
      <PageTitle
        title="Voortgang"
        sub={goalSentence(toMinutes(thisWeek.durationSeconds), thisWeek.goalMinutes, days)}
        action={
          <Link href="/activities/new" className="btn btn-primary">
            <PlusIcon />
            Activiteit toevoegen
          </Link>
        }
      />

      <div className="stagger grid grid-cols-[minmax(0,1fr)] gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <Panel
          title="Deze week"
          aside={
            <Link href="/settings" className="link">
              Doel aanpassen
            </Link>
          }
        >
          <div className="pt-2">
            <WeekGoal seconds={thisWeek.durationSeconds} goalMinutes={thisWeek.goalMinutes} days={days} large sentence={false} />
          </div>
        </Panel>

        <section className="panel grid grid-cols-2 content-center gap-x-6 gap-y-10 p-6 max-sm:gap-y-8 max-sm:p-5" aria-label="Deze week in cijfers">
          <Figure size="lg" label="Afstand deze week" value={<CountUp value={thisWeek.distanceMeters / 1000} format="decimal1" />} unit="km" />
          <Figure size="lg" label={thisWeek.count === 1 ? "Activiteit deze week" : "Activiteiten deze week"} value={<CountUp value={thisWeek.count} />} />
          <Figure size="lg" label="Energie deze week" value={<CountUp value={thisWeek.activeEnergyKcal} />} unit="kcal" />
          <div className="min-w-0">
            <div className={`figure whitespace-nowrap text-[56px] max-sm:text-[40px] ${streak >= 2 ? "text-volt" : ""}`}>
              <CountUp value={streak} />
            </div>
            <div className="figure-label mt-1 text-muted">{streak === 1 ? "Week op rij actief" : "Weken op rij actief"}</div>
          </div>
        </section>
      </div>

      <div className="stagger mt-4 grid grid-cols-[minmax(0,1fr)] gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <Panel
          title="Minuten per week"
          aside={
            <ul className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[13px]">
              <li className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-[3px] bg-accent" aria-hidden />
                Deze week
              </li>
              <li className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-[3px] bg-context" aria-hidden />
                Eerdere weken
              </li>
              <li className="flex items-center gap-1.5">
                <span className="h-[4px] w-2.5 bg-volt" aria-hidden />
                Doel gehaald
              </li>
              <li className="flex items-center gap-1.5">
                <span className="w-4 border-t border-dashed border-ink/70" aria-hidden />
                Weekdoel
              </li>
            </ul>
          }
        >
          <p className="mb-6 text-muted">
            In {weeksOnGoal} van de laatste {WEEKS} weken haalde je het doel van {thisWeek.goalMinutes} minuten.
          </p>
          <WeekColumns weeks={stats.weekly} goalMinutes={thisWeek.goalMinutes} height={284} />
        </Panel>

        <div className="flex flex-col gap-4">
          <Panel title="Per sport" aside={<span>laatste {WEEKS} weken</span>} className="flex flex-1 flex-col [&>div:last-child]:flex [&>div:last-child]:flex-1 [&>div:last-child]:flex-col">
            {stats.byType.length === 0 ? (
              <Empty>Nog niets opgenomen in de laatste {WEEKS} weken. Start je eerste ronde.</Empty>
            ) : (
              <>
                <SportList sports={stats.byType} />
                <p className="num mt-auto flex items-baseline justify-between gap-3 border-t border-line pt-4 text-muted">
                  <span>Alle sporten samen</span>
                  <span>
                    <span className="text-ink">{formatHoursMinutes(periodSeconds)}</span> · {formatCount(periodCount)}×
                  </span>
                </p>
              </>
            )}
          </Panel>
          <Panel title="Totaal" aside={<span>sinds {formatMonthYear(user.createdAt.toISOString())}</span>} >
            <div className="grid grid-cols-3 gap-x-6 gap-y-4 pt-1 max-sm:grid-cols-2">
              <Figure label="Activiteiten" value={<CountUp value={totals.count} />} />
              <Figure label="Uur" value={<CountUp value={totals.durationSeconds / 3600} format="decimal1" />} />
              <Figure label="Afstand" value={<CountUp value={totals.distanceMeters / 1000} format="decimal1" />} unit="km" />
            </div>
          </Panel>
        </div>
      </div>
    </>
  );
}
