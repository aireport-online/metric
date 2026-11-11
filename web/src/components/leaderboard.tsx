import Link from "next/link";
import { formatCount, formatHoursMinutes, formatKm } from "@/lib/format";
import type { Leaderboard, LeaderboardMetric } from "@/server/stats";
import { Track } from "./track";
import { Empty } from "./ui";

export function leaderboardValue(metric: LeaderboardMetric, value: number): string {
  if (metric === "duration") return formatHoursMinutes(value);
  if (metric === "distance") return `${formatKm(value, 1)} km`;
  return `${formatCount(value)}×`;
}

/**
 * The ranking as a starting grid: everyone in their own lane with a lane number, and a small track
 * that is as full as their share of the leader's total. Your own lane is tartan.
 */
export function LeaderboardList({ board, limit }: { board: Leaderboard; limit?: number }) {
  const entries = limit ? board.entries.slice(0, limit) : board.entries;
  const max = Math.max(...board.entries.map((entry) => entry.value), 0);
  if (board.entries.length <= 1) {
    return <Empty>Nodig vrienden uit om te zien wie deze week het meest beweegt.</Empty>;
  }
  return (
    <ol className="stagger flex flex-col">
      {entries.map((entry) => {
        const leads = entry.rank === 1 && entry.value > 0;
        return (
          <li key={entry.user.id} className="flex min-h-16 items-center gap-4 border-t border-line py-2.5 first:border-t-0">
            <span className={`figure w-7 flex-none text-center text-[36px] ${leads ? "text-volt" : entry.isMe ? "text-accent" : "text-quiet"}`}>
              {entry.rank}
            </span>
            <span className="min-w-0 flex-1">
              <Link href={`/u/${entry.user.username}`} className="block truncate font-medium hover:underline">
                {entry.isMe ? "Jij" : entry.user.displayName}
              </Link>
              <span className={`num block whitespace-nowrap text-[14px] leading-5 ${entry.value > 0 ? "text-muted" : "text-quiet"}`}>
                {leaderboardValue(board.metric, entry.value)}
              </span>
            </span>
            <Track
              className="flex-none"
              fixed
              width={88}
              aspect={2.2}
              thickness={6}
              lanes={[{ progress: max > 0 ? entry.value / max : 0, color: entry.isMe ? "var(--accent)" : "var(--text)" }]}
              label={`${max > 0 ? Math.round((entry.value / max) * 100) : 0}% van de koploper`}
            />
          </li>
        );
      })}
    </ol>
  );
}
