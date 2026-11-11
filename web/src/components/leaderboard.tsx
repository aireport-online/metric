import Link from "next/link";
import { formatCount, formatHoursMinutes, formatKm } from "@/lib/format";
import type { Leaderboard, LeaderboardMetric } from "@/server/stats";
import { Avatar, Empty } from "./ui";

export function leaderboardValue(metric: LeaderboardMetric, value: number): string {
  if (metric === "duration") return formatHoursMinutes(value);
  if (metric === "distance") return `${formatKm(value, 1)} km`;
  return `${formatCount(value)}×`;
}

/** Ranking where each row's fill is its bar: as wide as its share of the leader's total. */
export function LeaderboardList({ board, limit }: { board: Leaderboard; limit?: number }) {
  const entries = limit ? board.entries.slice(0, limit) : board.entries;
  const max = Math.max(...board.entries.map((entry) => entry.value), 0);
  if (board.entries.length <= 1) {
    return <Empty>Nodig vrienden uit om te zien wie deze week het meest beweegt.</Empty>;
  }
  return (
    <ol className="flex flex-col gap-0.5">
      {entries.map((entry) => (
        <li key={entry.user.id} className="relative flex h-11 items-center gap-3 px-2.5">
          {entry.value > 0 ? (
            <span
              aria-hidden
              className={`absolute inset-y-0 left-0 rounded-control ${entry.isMe ? "bg-hue/[0.14]" : "bg-raised"}`}
              style={{ width: `${Math.max((entry.value / max) * 100, 4)}%` }}
            />
          ) : null}
          <span className="num relative w-4 flex-none text-right text-muted">{entry.rank}</span>
          <span className="relative flex flex-none">
            <Avatar username={entry.user.username} name={entry.user.displayName} size={24} />
          </span>
          <Link href={`/u/${entry.user.username}`} className={`relative min-w-0 flex-1 truncate hover:underline ${entry.isMe ? "font-medium" : ""}`}>
            {entry.user.displayName}
            {entry.isMe ? <span className="font-normal text-muted"> (jij)</span> : null}
          </Link>
          <span className={`num relative flex-none ${entry.value > 0 ? "" : "text-muted"}`}>{leaderboardValue(board.metric, entry.value)}</span>
        </li>
      ))}
    </ol>
  );
}
