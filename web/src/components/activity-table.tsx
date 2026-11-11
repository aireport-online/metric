"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { loadOwnActivitiesAction } from "@/app/actions/activities";
import { ACTIVITY_INFO, VISIBILITY_LABEL } from "@/lib/activity-types";
import { formatClock, formatCount, formatKm, formatRate, formatWhen } from "@/lib/format";
import type { ActivityDto } from "@/server/serialize";
import { activityTitle } from "./activity-card";

const dash = <span className="text-muted">–</span>;

export function ActivityTable({
  initial,
  initialCursor,
  total,
  timeZone,
}: {
  initial: ActivityDto[];
  initialCursor: string | null;
  total: number;
  timeZone: string;
}) {
  const [items, setItems] = useState(initial);
  const [cursor, setCursor] = useState(initialCursor);
  const [failed, setFailed] = useState(false);
  const [pending, startTransition] = useTransition();

  return (
    <div className="panel">
      <table className="w-full">
        <thead>
          <tr className="text-[12px] text-muted">
            <th className="h-10 pl-5 text-left font-normal max-sm:pl-4">Activiteit</th>
            <th className="h-10 px-3 text-left font-normal max-sm:hidden">Wanneer</th>
            <th className="num h-10 px-3 text-right font-normal max-sm:pr-4">Duur</th>
            <th className="num h-10 px-3 text-right font-normal max-sm:hidden">Afstand</th>
            <th className="num h-10 px-3 text-right font-normal max-md:hidden">Tempo</th>
            <th className="h-10 pl-3 pr-5 text-left font-normal max-md:hidden">Zichtbaar voor</th>
          </tr>
        </thead>
        <tbody>
          {items.map((activity) => {
            const rate = formatRate(activity.type, activity.distanceMeters, activity.durationSeconds);
            const km = activity.distanceMeters ? `${formatKm(activity.distanceMeters)} km` : null;
            return (
              <tr key={activity.id} className="border-t border-rule">
                <td className="py-2.5 pl-5 max-sm:pl-4">
                  <Link href={`/activities/${activity.id}`} className="font-medium hover:underline">
                    {activityTitle(activity)}
                  </Link>
                  <div className="text-[12px] leading-5 text-muted">
                    {ACTIVITY_INFO[activity.type].label}
                    <span className="sm:hidden">
                      {" · "}
                      {formatWhen(activity.startedAt, timeZone)}
                      {km ? ` · ${km}` : ""}
                    </span>
                  </div>
                </td>
                <td className="whitespace-nowrap px-3 max-sm:hidden">{formatWhen(activity.startedAt, timeZone)}</td>
                <td className="num px-3 text-right max-sm:pr-4">{formatClock(activity.durationSeconds)}</td>
                <td className="num whitespace-nowrap px-3 text-right max-sm:hidden">
                  {activity.distanceMeters ? (
                    <>
                      {formatKm(activity.distanceMeters)} <span className="text-[12px] text-muted">km</span>
                    </>
                  ) : (
                    dash
                  )}
                </td>
                <td className="num whitespace-nowrap px-3 text-right max-md:hidden">
                  {rate ? (
                    <>
                      {rate.value} <span className="text-[12px] text-muted">{rate.unit}</span>
                    </>
                  ) : (
                    dash
                  )}
                </td>
                <td className="whitespace-nowrap pl-3 pr-5 text-muted max-md:hidden">{VISIBILITY_LABEL[activity.visibility]}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <div className="flex flex-wrap items-center justify-between gap-3 border-t border-rule px-5 py-3 max-sm:px-4">
        <p className="num text-muted">
          1–{formatCount(items.length)} van {formatCount(Math.max(total, items.length))}
        </p>
        {failed ? (
          <p role="alert" className="text-negative">
            Laden is niet gelukt. Probeer het opnieuw.
          </p>
        ) : null}
        {cursor ? (
          <button
            type="button"
            className="btn btn-sm btn-secondary"
            disabled={pending}
            onClick={() =>
              startTransition(async () => {
                try {
                  const page = await loadOwnActivitiesAction(cursor);
                  setFailed(false);
                  setItems((current) => {
                    const seen = new Set(current.map((item) => item.id));
                    return [...current, ...page.activities.filter((item) => !seen.has(item.id))];
                  });
                  setCursor(page.nextCursor);
                } catch {
                  setFailed(true);
                }
              })
            }
          >
            {pending ? "Laden…" : "Meer laden"}
          </button>
        ) : null}
      </div>
    </div>
  );
}
