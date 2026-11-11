"use client";

import { useState, type CSSProperties } from "react";
import { ACTIVITY_INFO } from "@/lib/activity-types";
import type { ActivityType } from "@/lib/constants";
import { formatCount, formatHoursMinutes, formatKm, formatWeekStart, toMinutes } from "@/lib/format";
import { sportColor } from "@/lib/sports";
import { SportIcon } from "./icons";

export type Week = { weekStart: string; durationSeconds: number; distanceMeters: number; count: number };

/** Round steps with the top tick above the tallest value, so no column touches the plot's edge. */
export function minuteScale(maxMinutes: number): { top: number; ticks: number[] } {
  const steps = [15, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800];
  const step = steps.find((s) => Math.ceil((maxMinutes + 1) / s) <= 4) ?? steps[steps.length - 1];
  const count = Math.max(2, Math.ceil((maxMinutes + 1) / step));
  return { top: count * step, ticks: Array.from({ length: count + 1 }, (_, i) => i * step) };
}

/**
 * Minutes per week as columns that grow from the baseline. The running week is tartan, earlier
 * weeks are neutral context, a week that reached the goal carries a volt finish cap, and the goal
 * itself is a dashed reference line labelled at its end.
 */
export function WeekColumns({
  weeks,
  goalMinutes,
  height = 200,
  table = true,
}: {
  weeks: Week[];
  goalMinutes: number;
  height?: number;
  /** The same numbers as a table, behind a disclosure. */
  table?: boolean;
}) {
  const [active, setActive] = useState<number | null>(null);
  const minutes = weeks.map((week) => toMinutes(week.durationSeconds));
  const { top, ticks } = minuteScale(Math.max(goalMinutes, ...minutes));
  const last = weeks.length - 1;
  const labelEvery = weeks.length > 8 ? 3 : weeks.length > 4 ? 2 : 1;

  return (
    <figure className="@container">
      <div className="relative" style={{ height }} onMouseLeave={() => setActive(null)}>
        {ticks.map((tick) => (
          <div key={tick} className="absolute inset-x-0 flex items-center" style={{ bottom: `${(tick / top) * 100}%`, height: 0 }}>
            <span className="num w-8 flex-none pr-2 text-right text-[12px] leading-none text-quiet">{tick}</span>
            <span className={`h-px flex-1 ${tick === 0 ? "bg-control" : "bg-grid"}`} />
          </div>
        ))}

        <div className="absolute inset-y-0 left-8 right-[72px] flex items-end gap-[3px] sm:gap-2">
          {weeks.map((week, i) => {
            const share = (minutes[i] / top) * 100;
            const align = i < 2 ? "left-0" : i > last - 2 ? "right-0" : "left-1/2 -translate-x-1/2";
            return (
              <div
                key={week.weekStart}
                tabIndex={0}
                role="img"
                aria-label={`Week van ${formatWeekStart(week.weekStart)}: ${minutes[i]} minuten, ${week.count} activiteiten`}
                className="group relative flex h-full flex-1 items-end justify-center outline-none"
                onMouseEnter={() => setActive(i)}
                onFocus={() => setActive(i)}
                onBlur={() => setActive(null)}
              >
                {active === i ? <span aria-hidden className="absolute inset-y-0 -inset-x-px rounded-[6px] bg-ink/[0.06]" /> : null}
                {minutes[i] > 0 ? (
                  <span
                    className={`grow-y relative w-full max-w-[36px] overflow-hidden rounded-t-[6px] ${i === last ? "bg-accent" : "bg-context"} group-focus-visible:outline-2 group-focus-visible:outline-offset-2 group-focus-visible:outline-ink`}
                    style={{ height: `max(3px, ${share}%)`, "--i": i } as CSSProperties}
                  >
                    {minutes[i] >= goalMinutes ? <span aria-hidden className="absolute inset-x-0 top-0 h-[4px] bg-volt" /> : null}
                  </span>
                ) : null}
                {active === i ? (
                  <div
                    role="tooltip"
                    className={`pointer-events-none absolute z-10 whitespace-nowrap rounded-chip bg-raised px-3 py-2 text-[13px] leading-5 ring-1 ring-control ${align}`}
                    style={{ bottom: `calc(${share}% + 8px)` }}
                  >
                    <div className="text-muted">Week van {formatWeekStart(week.weekStart)}</div>
                    <div className="num font-medium text-ink">
                      {formatHoursMinutes(week.durationSeconds)} · {week.count} {week.count === 1 ? "activiteit" : "activiteiten"}
                    </div>
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>

        <div className="pointer-events-none absolute inset-x-0 left-8 flex items-center" style={{ bottom: `${(goalMinutes / top) * 100}%`, height: 0 }}>
          <span className="h-px flex-1 border-t border-dashed border-ink/70" />
          <span className="num w-[72px] flex-none pl-2 text-[12px] leading-none text-ink">Doel {goalMinutes}</span>
        </div>
      </div>

      <div className="ml-8 mr-[72px] mt-2 flex gap-[3px] sm:gap-2" aria-hidden>
        {weeks.map((week, i) => (
          <span key={week.weekStart} className="relative h-4 flex-1 text-[12px] leading-4 text-quiet">
            {(last - i) % labelEvery === 0 ? (
              // In a narrow panel every other label is dropped, so the dates never run into each other.
              <span className={`absolute whitespace-nowrap ${(last - i) % (labelEvery * 2) === 0 ? "" : "@max-[400px]:hidden"} ${i === last ? "right-0 text-ink" : i === 0 ? "left-0" : "left-1/2 -translate-x-1/2"}`}>
                {formatWeekStart(week.weekStart)}
              </span>
            ) : null}
          </span>
        ))}
      </div>

      {table ? (
      <details className="mt-3 text-[14px] text-muted">
        <summary className="inline-flex h-8 cursor-pointer items-center hover:text-ink">Toon als tabel</summary>
        <table className="num mt-1 w-full max-w-md text-[14px] text-ink">
          <thead>
            <tr className="text-[13px] text-muted">
              <th className="py-1.5 text-left font-normal">Week van</th>
              <th className="py-1.5 text-right font-normal">Tijd</th>
              <th className="py-1.5 text-right font-normal">Afstand</th>
              <th className="py-1.5 text-right font-normal">Activiteiten</th>
            </tr>
          </thead>
          <tbody>
            {[...weeks].reverse().map((week) => (
              <tr key={week.weekStart} className="border-t border-rule">
                <td className="py-1.5">{formatWeekStart(week.weekStart)}</td>
                <td className="py-1.5 text-right">{formatHoursMinutes(week.durationSeconds)}</td>
                <td className="py-1.5 text-right">{formatKm(week.distanceMeters, 1)} km</td>
                <td className="py-1.5 text-right">{formatCount(week.count)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
      ) : null}
    </figure>
  );
}

export type SportShare = { type: ActivityType; count: number; durationSeconds: number; distanceMeters: number };

/** Ranked list: each sport with its icon, its name and one thin lane in its own tint. */
export function SportList({ sports }: { sports: SportShare[] }) {
  const max = Math.max(...sports.map((sport) => sport.durationSeconds), 1);
  return (
    <ol className="flex flex-col gap-4">
      {sports.map((sport, i) => (
        <li key={sport.type}>
          <div className="flex items-center justify-between gap-3">
            <span className="flex items-center gap-2.5 font-medium">
              <SportIcon type={sport.type} />
              {ACTIVITY_INFO[sport.type].label}
            </span>
            <span className="num text-muted">
              <span className="text-ink">{formatHoursMinutes(sport.durationSeconds)}</span> · {sport.count}×
            </span>
          </div>
          <div className="mt-2 h-[6px] rounded-full bg-line">
            <div
              className="grow-x h-full rounded-full"
              style={{ width: `${Math.max((sport.durationSeconds / max) * 100, 2)}%`, background: sportColor(sport.type), "--i": Math.min(i, 6) } as CSSProperties}
            />
          </div>
        </li>
      ))}
    </ol>
  );
}
