import type { Metadata } from "next";
import Link from "next/link";
import { ActivityTable } from "@/components/activity-table";
import { PlusIcon } from "@/components/icons";
import { Empty, PageTitle, Panel } from "@/components/ui";
import { formatCount, formatHoursMinutes, formatKm } from "@/lib/format";
import { listOwnActivities } from "@/server/activities";
import { getTimeZone, requireUser } from "@/server/session";
import { getStats } from "@/server/stats";

export const metadata: Metadata = { title: "Activiteiten" };

export default async function ActivitiesPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  const [page, stats] = await Promise.all([listOwnActivities(user.id, { limit: 30 }), getStats(user, 1, timeZone)]);
  const { totals } = stats;

  return (
    <>
      <PageTitle
        title="Activiteiten"
        sub={
          totals.count > 0
            ? `${formatCount(totals.count)} ${totals.count === 1 ? "activiteit" : "activiteiten"} · ${formatHoursMinutes(totals.durationSeconds)} · ${formatKm(totals.distanceMeters, 1)} km`
            : undefined
        }
        action={
          <Link href="/activities/new" className="btn btn-primary">
            <PlusIcon />
            Activiteit toevoegen
          </Link>
        }
      />
      {page.activities.length === 0 ? (
        <Panel title="Nog geen activiteiten">
          <Empty>
            Neem een workout op met de iPhone- of Watch-app, of{" "}
            <Link href="/activities/new" className="link">
              voeg er hier een toe
            </Link>
            .
          </Empty>
        </Panel>
      ) : (
        <ActivityTable initial={page.activities} initialCursor={page.nextCursor} total={totals.count} timeZone={timeZone} />
      )}
    </>
  );
}
