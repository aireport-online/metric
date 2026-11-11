import type { Metadata } from "next";
import Link from "next/link";
import { SportList, WeekColumns } from "@/components/charts";
import { PlusIcon } from "@/components/icons";
import { Empty, PageTitle, Panel } from "@/components/ui";
import { goalSentence, WeekGoal } from "@/components/week-goal";
import { formatCount, formatHoursMinutes, formatKm, formatMonthYear, toMinutes } from "@/lib/format";
import { getTimeZone, requireUser } from "@/server/session";
import { getStats, getWeekDays } from "@/server/stats";

export const metadata: Metadata = { title: "Voortgang" };

const WEEKS = 12;

function Row({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-t border-rule py-2.5">
      <dt className="text-muted">{label}</dt>
      <dd className="num">
        {value}
        {unit ? <span className="ml-1 text-[12px] text-muted">{unit}</span> : null}
      </dd>
    </div>
  );
}

export default async function DashboardPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  const [stats, days] = await Promise.all([getStats(user, WEEKS, timeZone), getWeekDays(user.id, timeZone)]);
  const { thisWeek, totals } = stats;
  // The foot of "Per sport" is the sum of the rows above it.
  const periodSeconds = stats.byType.reduce((sum, sport) => sum + sport.durationSeconds, 0);
  const periodCount = stats.byType.reduce((sum, sport) => sum + sport.count, 0);
  const weeksOnGoal = stats.weekly.filter((week) => toMinutes(week.durationSeconds) >= thisWeek.goalMinutes).length;

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

      {/* 364 + 12 + 776 = 1152 */}
      <div className="grid gap-3 lg:grid-cols-[364px_minmax(0,1fr)]">
        <Panel
          title="Deze week"
          aside={
            <Link href="/settings" className="link">
              Doel aanpassen
            </Link>
          }
        >
          <WeekGoal seconds={thisWeek.durationSeconds} goalMinutes={thisWeek.goalMinutes} days={days} large />
          <dl className="mt-4">
            <Row label="Activiteiten" value={formatCount(thisWeek.count)} />
            <Row label="Afstand" value={formatKm(thisWeek.distanceMeters, 1)} unit="km" />
            <Row label="Energie" value={formatCount(thisWeek.activeEnergyKcal)} unit="kcal" />
            <Row
              label="Reeks"
              value={formatCount(stats.currentStreakWeeks)}
              unit={stats.currentStreakWeeks === 1 ? "week op rij actief" : "weken op rij actief"}
            />
          </dl>
        </Panel>

        <Panel
          title="Minuten per week"
          aside={
            <ul className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[12px]">
              <li className="flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-[2px] bg-hue" aria-hidden />
                Deze week
              </li>
              <li className="flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-[2px] bg-context" aria-hidden />
                Eerdere weken
              </li>
              <li className="flex items-center gap-1.5">
                <span className="w-4 border-t border-dashed border-ink/60" aria-hidden />
                Weekdoel
              </li>
            </ul>
          }
        >
          <p className="mb-5 text-muted">
            In {weeksOnGoal} van de laatste {WEEKS} weken haalde je het doel van {thisWeek.goalMinutes} minuten.
          </p>
          <WeekColumns weeks={stats.weekly} goalMinutes={thisWeek.goalMinutes} height={284} />
        </Panel>
      </div>

      {/* 776 + 12 + 364 = 1152 */}
      <div className="mt-3 grid gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <Panel title="Per sport" aside={<span className="text-[12px]">laatste {WEEKS} weken</span>} className="flex flex-col [&>div:last-child]:flex [&>div:last-child]:flex-1 [&>div:last-child]:flex-col">
          {stats.byType.length === 0 ? (
            <Empty>Geen activiteiten in de laatste {WEEKS} weken.</Empty>
          ) : (
            <>
              <SportList sports={stats.byType} />
              <p className="num mt-auto flex items-baseline justify-between gap-3 border-t border-rule pt-3 text-muted">
                <span>Alle sporten samen</span>
                <span>
                  <span className="text-ink">{formatHoursMinutes(periodSeconds)}</span> · {formatCount(periodCount)}×
                </span>
              </p>
            </>
          )}
        </Panel>
        <Panel title="Totaal" aside={<span className="text-[12px]">sinds {formatMonthYear(user.createdAt.toISOString())}</span>}>
          <dl className="-mt-1">
            <div className="flex items-baseline justify-between gap-3 py-2.5">
              <dt className="text-muted">Activiteiten</dt>
              <dd className="num">{formatCount(totals.count)}</dd>
            </div>
            <Row label="Tijd" value={formatHoursMinutes(totals.durationSeconds)} />
            <Row label="Afstand" value={formatKm(totals.distanceMeters, 1)} unit="km" />
          </dl>
        </Panel>
      </div>
    </>
  );
}
