"use client";

import { useState } from "react";
import { ACTIVITY_INFO } from "@/lib/activity-types";
import type { ActivityType } from "@/lib/constants";
import { formatCount, formatHoursMinutes, formatKm, formatWeekStart, toMinutes } from "@/lib/format";

export type Week = { weekStart: string; durationSeconds: number; distanceMeters: number; count: number };

/** Round steps with the top tick above the tallest value, so no column touches the plot's edge. */
export function minuteScale(maxMinutes: number): { top: number; ticks: number[] } {
  const steps = [15, 30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800];
  const step = steps.find((s) => Math.ceil((maxMinutes + 1) / s) <= 4) ?? steps[steps.length - 1];
  const count = Math.max(2, Math.ceil((maxMinutes + 1) / step));
  return { top: count * step, ticks: Array.from({ length: count + 1 }, (_, i) => i * step) };
}

const tickLabel = (minutes: number) => (minutes >= 120 && minutes % 60 === 0 ? `${minutes / 60} u` : `${minutes}`);

/**
 * Minutes per week as columns. The running week carries the hue, earlier weeks are grey context,
 * and the weekly goal is a dashed reference line labelled at its end.
 */
export function WeekColumns({ weeks, goalMinutes, height = 200 }: { weeks: Week[]; goalMinutes: number; height?: number }) {
  const [active, setActive] = useState<number | null>(null);
  const minutes = weeks.map((week) => toMinutes(week.durationSeconds));
  const { top, ticks } = minuteScale(Math.max(goalMinutes, ...minutes));
  const last = weeks.length - 1;
  const labelEvery = weeks.length > 8 ? 3 : weeks.length > 4 ? 2 : 1;

  return (
    <figure>
      <div className="relative" style={{ height }} onMouseLeave={() => setActive(null)}>
        {ticks.map((tick) => (
          <div key={tick} className="absolute inset-x-0 flex items-center" style={{ bottom: `${(tick / top) * 100}%`, height: 0 }}>
            <span className="num w-8 flex-none pr-2 text-right text-[12px] leading-none text-muted">{tickLabel(tick)}</span>
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
                {active === i ? <span aria-hidden className="absolute inset-y-0 -inset-x-px rounded-chip bg-ink/[0.04]" /> : null}
                {minutes[i] > 0 ? (
                  <span
                    className={`relative w-full max-w-[36px] rounded-t-[4px] ${i === last ? "bg-hue" : "bg-context"} group-focus-visible:outline-2 group-focus-visible:outline-offset-2 group-focus-visible:outline-ink`}
                    style={{ height: `max(2px, ${share}%)` }}
                  />
                ) : null}
                {active === i ? (
                  <div
                    role="tooltip"
                    className={`pointer-events-none absolute z-10 whitespace-nowrap rounded-control border border-line bg-surface px-2.5 py-1.5 text-[12px] leading-4 shadow-[0_2px_8px_rgba(0,0,0,0.08)] ${align}`}
                    style={{ bottom: `calc(${share}% + 8px)` }}
                  >
                    <div className="text-muted">Week van {formatWeekStart(week.weekStart)}</div>
                    <div className="num font-medium">
                      {formatHoursMinutes(week.durationSeconds)} · {week.count} {week.count === 1 ? "activiteit" : "activiteiten"}
                    </div>
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>

        <div className="pointer-events-none absolute inset-x-0 left-8 flex items-center" style={{ bottom: `${(goalMinutes / top) * 100}%`, height: 0 }}>
          <span className="h-px flex-1 border-t border-dashed border-ink/60" />
          <span className="num w-[72px] flex-none pl-2 text-[12px] leading-none text-ink">Doel {goalMinutes}</span>
        </div>
      </div>

      <div className="ml-8 mr-[72px] mt-2 flex gap-[3px] sm:gap-2" aria-hidden>
        {weeks.map((week, i) => (
          <span key={week.weekStart} className="relative h-4 flex-1 text-[12px] leading-4 text-muted">
            {(last - i) % labelEvery === 0 ? (
              <span className={`absolute whitespace-nowrap ${i === last ? "right-0 text-ink" : i === 0 ? "left-0" : "left-1/2 -translate-x-1/2"}`}>
                {formatWeekStart(week.weekStart)}
              </span>
            ) : null}
          </span>
        ))}
      </div>

      <details className="mt-3 text-[12px] text-muted">
        <summary className="inline-flex h-8 cursor-pointer items-center hover:text-ink">Toon als tabel</summary>
        <table className="num mt-1 w-full max-w-md text-[14px] text-ink">
          <thead>
            <tr className="text-[12px] text-muted">
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
    </figure>
  );
}

export type SportShare = { type: ActivityType; count: number; durationSeconds: number; distanceMeters: number };

/** Ranked list: one thin bar per sport, the largest in ink and the rest in grey. */
export function SportList({ sports }: { sports: SportShare[] }) {
  const max = Math.max(...sports.map((sport) => sport.durationSeconds), 1);
  return (
    <ol className="flex flex-col gap-3">
      {sports.map((sport, i) => (
        <li key={sport.type}>
          <div className="flex items-baseline justify-between gap-3">
            <span className="font-medium">{ACTIVITY_INFO[sport.type].label}</span>
            <span className="num text-muted">
              <span className="text-ink">{formatHoursMinutes(sport.durationSeconds)}</span> · {sport.count}×
            </span>
          </div>
          <div className="mt-1.5 h-[3px] rounded-full bg-rule">
            <div className={`h-full rounded-full ${i === 0 ? "bg-ink" : "bg-context"}`} style={{ width: `${Math.max((sport.durationSeconds / max) * 100, 1)}%` }} />
          </div>
        </li>
      ))}
    </ol>
  );
}
