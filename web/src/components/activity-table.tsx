"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { loadOwnActivitiesAction } from "@/app/actions/activities";
import { ACTIVITY_INFO, SOURCE_LABEL, VISIBILITY_LABEL, activityTitle } from "@/lib/activity-types";
import { formatClock, formatCount, formatKm, formatRate, formatWhen } from "@/lib/format";
import type { ActivityDto } from "@/server/serialize";
import { SportIcon } from "./icons";
import { useMorePages } from "./use-more-pages";

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
  const { items, cursor, append } = useMorePages(initial, initialCursor);
  const [failed, setFailed] = useState(false);
  const [pending, startTransition] = useTransition();

  return (
    <div className="panel rise overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="text-[14px] text-quiet">
            <th className="h-12 pl-6 text-left font-normal max-sm:pl-5">Activiteit</th>
            <th className="h-12 px-3 text-left font-normal max-sm:hidden">Wanneer</th>
            <th className="num h-12 px-3 text-right font-normal max-sm:pr-4">Duur</th>
            <th className="num h-12 px-3 text-right font-normal max-sm:hidden">Afstand</th>
            <th className="num h-12 px-3 text-right font-normal max-md:hidden">Tempo</th>
            <th className="h-12 pl-3 pr-6 text-right font-normal max-md:hidden">Zichtbaar voor</th>
          </tr>
        </thead>
        <tbody>
          {items.map((activity) => {
            const rate = formatRate(activity.type, activity.distanceMeters, activity.durationSeconds);
            const km = activity.distanceMeters ? `${formatKm(activity.distanceMeters)} km` : null;
            return (
              <tr key={activity.id} className="border-t border-rule">
                <td className="py-3.5 pl-6 max-sm:pl-5">
                  <Link href={`/activities/${activity.id}`} className="flex items-center gap-2.5 font-semibold hover:underline">
                    <SportIcon type={activity.type} size={18} />
                    <span>{activityTitle(activity)}</span>
                  </Link>
                  <div className="pl-[28px] text-[14px] leading-5 text-muted">
                    {activity.title ? ACTIVITY_INFO[activity.type].label : `via ${SOURCE_LABEL[activity.source]}`}
                    <span className="sm:hidden">
                      {" · "}
                      {formatWhen(activity.startedAt, timeZone)}
                      {km ? ` · ${km}` : ""}
                    </span>
                  </div>
                </td>
                <td className="whitespace-nowrap px-3 max-sm:hidden">{formatWhen(activity.startedAt, timeZone)}</td>
                <td className="figure px-3 text-right text-[24px] max-sm:pr-5">{formatClock(activity.durationSeconds)}</td>
                <td className="figure whitespace-nowrap px-3 text-right text-[24px] max-sm:hidden">
                  {activity.distanceMeters ? (
                    <>
                      {formatKm(activity.distanceMeters)} <span className="figure-label not-italic text-quiet">km</span>
                    </>
                  ) : (
                    dash
                  )}
                </td>
                <td className="figure whitespace-nowrap px-3 text-right text-[24px] max-md:hidden">
                  {rate ? (
                    <>
                      {rate.value} <span className="figure-label not-italic text-quiet">{rate.unit}</span>
                    </>
                  ) : (
                    dash
                  )}
                </td>
                <td className="whitespace-nowrap pl-3 pr-6 text-right text-muted max-md:hidden">{VISIBILITY_LABEL[activity.visibility]}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line px-6 py-4 max-sm:px-5">
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
                  append(page);
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
