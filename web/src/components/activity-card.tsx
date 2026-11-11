"use client";

import Link from "next/link";
import { useOptimistic, useState, useTransition } from "react";
import { setKudosAction } from "@/app/actions/activities";
import { ACTIVITY_INFO, activityTitle } from "@/lib/activity-types";
import { formatClock, formatKm, formatRate, formatWhen } from "@/lib/format";
import type { ActivityDto } from "@/server/serialize";
import { CommentIcon, KudosIcon } from "./icons";
import { RouteThumb } from "./route-map";
import { Avatar, Figure } from "./ui";

export type CardActivity = ActivityDto & { routePreview?: [number, number][] | null };

export function KudosButton({
  activityId,
  count,
  on,
  canKudo,
  size = "sm",
}: {
  activityId: string;
  count: number;
  on: boolean;
  canKudo: boolean;
  size?: "sm" | "md";
}) {
  const [state, setState] = useState({ count, on });
  const [optimistic, setOptimistic] = useOptimistic(state);
  const [, startTransition] = useTransition();
  const sizing = size === "sm" ? "btn-sm" : "";

  if (!canKudo) {
    return (
      <span className="num inline-flex h-8 items-center gap-1.5 text-muted">
        <KudosIcon />
        {count} kudos
      </span>
    );
  }
  return (
    <button
      type="button"
      aria-pressed={optimistic.on}
      className={`btn ${sizing} ${optimistic.on ? "btn-on" : "btn-outline"}`}
      onClick={() =>
        startTransition(async () => {
          const next = { on: !optimistic.on, count: optimistic.count + (optimistic.on ? -1 : 1) };
          setOptimistic(next);
          try {
            const result = await setKudosAction(activityId, next.on);
            setState({ count: result.kudosCount, on: result.hasKudoed });
          } catch {
            setState((current) => ({ ...current }));
          }
        })
      }
    >
      <KudosIcon />
      <span>Kudos</span>
      <span className="num">{optimistic.count}</span>
    </button>
  );
}

export function ActivityFigures({ activity }: { activity: ActivityDto }) {
  const rate = formatRate(activity.type, activity.distanceMeters, activity.durationSeconds);
  return (
    <div className="flex flex-wrap gap-x-8 gap-y-2">
      {activity.distanceMeters ? <Figure label="Afstand" value={formatKm(activity.distanceMeters)} unit="km" /> : null}
      <Figure label="Duur" value={formatClock(activity.durationSeconds)} />
      {rate ? <Figure label={rate.label} value={rate.value} unit={rate.unit} /> : null}
      {activity.avgHeartRate ? <Figure label="Hartslag" value={activity.avgHeartRate} unit="bpm" /> : null}
    </div>
  );
}

export function ActivityCard({
  activity,
  timeZone,
  viewerId,
}: {
  activity: CardActivity;
  timeZone: string;
  viewerId: string | null;
}) {
  const info = ACTIVITY_INFO[activity.type];
  const href = `/activities/${activity.id}`;
  return (
    <article className="panel p-5 max-sm:p-4">
      <div className="flex items-start gap-3">
        <Link href={`/u/${activity.user.username}`} tabIndex={-1} aria-hidden>
          <Avatar username={activity.user.username} name={activity.user.displayName} size={40} />
        </Link>
        <div className="min-w-0 flex-1">
          <p className="truncate">
            <Link href={`/u/${activity.user.username}`} className="font-medium hover:underline">
              {activity.user.displayName}
            </Link>{" "}
            <span className="text-muted">{info.verb}</span>
          </p>
          <p className="text-[12px] leading-5 text-muted">
            {formatWhen(activity.startedAt, timeZone)}
            {activity.visibility === "private" ? " · alleen zichtbaar voor jou" : ""}
          </p>
          <h2 className="mt-2 text-[16px] font-medium leading-6">
            <Link href={href} className="hover:underline">
              {activityTitle(activity)}
            </Link>
          </h2>
        </div>
        {activity.routePreview ? (
          <Link href={href} tabIndex={-1} aria-hidden className="flex-none">
            <RouteThumb route={activity.routePreview} />
          </Link>
        ) : null}
      </div>

      <div className="mt-3 sm:pl-[52px]">
        <ActivityFigures activity={activity} />
        <div className="mt-4 flex items-center gap-2">
          <KudosButton activityId={activity.id} count={activity.kudosCount} on={activity.hasKudoed} canKudo={viewerId !== null} />
          <Link href={`${href}#reacties`} className="btn btn-sm btn-outline">
            <CommentIcon />
            <span>Reacties</span>
            <span className="num">{activity.commentCount}</span>
          </Link>
        </div>
      </div>
    </article>
  );
}
