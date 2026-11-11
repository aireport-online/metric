import type { Metadata } from "next";
import Link from "next/link";
import { FeedList } from "@/components/feed-list";
import { PlusIcon } from "@/components/icons";
import { LeaderboardList, leaderboardValue } from "@/components/leaderboard";
import { Empty, PageTitle, Panel } from "@/components/ui";
import { WeekGoal } from "@/components/week-goal";
import { listFeed } from "@/server/activities";
import { getTimeZone, requireUser } from "@/server/session";
import { getLeaderboard, getStats, getWeekDays } from "@/server/stats";

export const metadata: Metadata = { title: "Feed" };

export default async function FeedPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  const [feed, stats, days, board] = await Promise.all([
    listFeed(user.id, { limit: 20, withRoutePreview: true }),
    getStats(user, 1, timeZone),
    getWeekDays(user.id, timeZone),
    getLeaderboard(user, "duration", timeZone),
  ]);

  const leader = board.entries[0];
  const finding =
    board.entries.length > 1 && leader && leader.value > 0
      ? `${leader.isMe ? "Jij staat" : `${leader.user.displayName} staat`} deze week bovenaan met ${leaderboardValue("duration", leader.value)}.`
      : undefined;

  return (
    <>
      <PageTitle
        title="Feed"
        sub={finding}
        action={
          <Link href="/activities/new" className="btn btn-primary">
            <PlusIcon />
            Activiteit toevoegen
          </Link>
        }
      />
      <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <div>
          {feed.activities.length === 0 ? (
            <Panel title="Nog niets te zien">
              <Empty>
                Workouts van je iPhone en Apple Watch verschijnen hier vanzelf zodra de app ze heeft gesynchroniseerd.{" "}
                <Link href="/activities/new" className="link">
                  Voeg zelf een activiteit toe
                </Link>{" "}
                of{" "}
                <Link href="/friends" className="link">
                  nodig vrienden uit
                </Link>
                .
              </Empty>
            </Panel>
          ) : (
            <FeedList initial={feed.activities} initialCursor={feed.nextCursor} timeZone={timeZone} viewerId={user.id} />
          )}
        </div>
        <aside className="flex flex-col gap-3 max-lg:order-first">
          <Panel
            title="Deze week"
            aside={
              <Link href="/dashboard" className="link">
                Voortgang
              </Link>
            }
          >
            <WeekGoal seconds={stats.thisWeek.durationSeconds} goalMinutes={stats.thisWeek.goalMinutes} days={days} />
          </Panel>
          <Panel
            title="Ranglijst"
            className="max-lg:hidden"
            aside={
              <Link href="/friends" className="link">
                Bekijk alles
              </Link>
            }
          >
            <LeaderboardList board={board} limit={5} />
          </Panel>
        </aside>
      </div>
    </>
  );
}
