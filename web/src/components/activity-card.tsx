"use client";

import Link from "next/link";
import { useOptimistic, useState, useTransition } from "react";
import { setKudosAction } from "@/app/actions/activities";
import { ACTIVITY_INFO, activityTitle } from "@/lib/activity-types";
import { formatClock, formatKm, formatRate, formatWhen } from "@/lib/format";
import { sportColor } from "@/lib/sports";
import type { ActivityDto } from "@/server/serialize";
import { CommentIcon, KudosIcon, SportIcon } from "./icons";
import { RouteThumb } from "./route-map";
import { Avatar, Figure } from "./ui";

export type CardActivity = ActivityDto & { routePreview?: [number, number][] | null };

/**
 * Kudos: the icon springs, the button turns tartan and the count ticks over. The spring is keyed
 * on the number of presses, so it replays on every press and never on first render.
 */
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
  const [presses, setPresses] = useState(0);
  const [, startTransition] = useTransition();
  const sizing = size === "sm" ? "btn-sm" : "";

  if (!canKudo) {
    return (
      <span className="num inline-flex h-9 items-center gap-1.5 text-muted">
        <KudosIcon />
        {count} kudos
      </span>
    );
  }
  return (
    <button
      type="button"
      aria-pressed={optimistic.on}
      data-kudos
      className={`btn ${sizing} ${optimistic.on ? "btn-on" : "btn-outline"}`}
      onClick={() => {
        setPresses((n) => n + 1);
        startTransition(async () => {
          const next = { on: !optimistic.on, count: optimistic.count + (optimistic.on ? -1 : 1) };
          setOptimistic(next);
          try {
            const result = await setKudosAction(activityId, next.on);
            setState({ count: result.kudosCount, on: result.hasKudoed });
          } catch {
            setState((current) => ({ ...current }));
          }
        });
      }}
    >
      <span key={presses} className={presses > 0 && optimistic.on ? "kick inline-flex" : "inline-flex"}>
        <KudosIcon />
      </span>
      <span>Kudos</span>
      <span key={`n${optimistic.count}`} className={`num ${presses > 0 ? "rise" : ""}`}>
        {optimistic.count}
      </span>
    </button>
  );
}

export function ActivityFigures({ activity }: { activity: ActivityDto }) {
  const rate = formatRate(activity.type, activity.distanceMeters, activity.durationSeconds);
  return (
    <div className="flex flex-wrap gap-x-9 gap-y-3 max-sm:gap-x-6">
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
    <article className="panel relative overflow-hidden p-6 pl-7 max-sm:p-5 max-sm:pl-6">
      {/* The sport's lane down the card's edge. */}
      <span aria-hidden className="absolute inset-y-0 left-0 w-[5px]" style={{ background: sportColor(activity.type) }} />
      <div className="flex items-start gap-3">
        <Link href={`/u/${activity.user.username}`} tabIndex={-1} aria-hidden>
          <Avatar name={activity.user.displayName} size={44} />
        </Link>
        <div className="min-w-0 flex-1">
          <p className="truncate">
            <Link href={`/u/${activity.user.username}`} className="font-semibold hover:underline">
              {activity.user.displayName}
            </Link>{" "}
            <span className="text-muted">{info.verb}</span>
          </p>
          <p className="flex items-center gap-1.5 text-[14px] leading-5 text-muted">
            <SportIcon type={activity.type} size={16} />
            <span className="min-w-0 truncate">
              {info.label} · {formatWhen(activity.startedAt, timeZone)}
              {activity.visibility === "private" ? " · alleen jij" : ""}
            </span>
          </p>
        </div>
        {activity.routePreview ? (
          <Link href={href} tabIndex={-1} aria-hidden className="flex-none">
            <RouteThumb route={activity.routePreview} />
          </Link>
        ) : null}
      </div>

      <h2 className="display mt-4 text-[26px] leading-[1.1]">
        <Link href={href} className="hover:underline">
          {activityTitle(activity)}
        </Link>
      </h2>

      <div className="mt-4">
        <ActivityFigures activity={activity} />
        <div className="mt-5 flex items-center gap-2">
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
