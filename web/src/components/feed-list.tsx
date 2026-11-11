"use client";

import { useState, useTransition } from "react";
import { loadFeedAction } from "@/app/actions/activities";
import { ActivityCard, type CardActivity } from "./activity-card";
import { useMorePages } from "./use-more-pages";

export function FeedList({
  initial,
  initialCursor,
  timeZone,
  viewerId,
}: {
  initial: CardActivity[];
  initialCursor: string | null;
  timeZone: string;
  viewerId: string;
}) {
  const { items, cursor, append } = useMorePages(initial, initialCursor);
  const [failed, setFailed] = useState(false);
  const [pending, startTransition] = useTransition();

  return (
    <div className="stagger flex flex-col gap-4">
      {items.map((activity) => (
        <ActivityCard key={activity.id} activity={activity} timeZone={timeZone} viewerId={viewerId} />
      ))}
      {cursor ? (
        <div className="flex items-center gap-3">
          <button
            type="button"
            className="btn btn-secondary"
            disabled={pending}
            onClick={() =>
              startTransition(async () => {
                try {
                  const page = await loadFeedAction(cursor);
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
          {failed ? (
            <p role="alert" className="text-negative">
              Laden is niet gelukt. Probeer het opnieuw.
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
