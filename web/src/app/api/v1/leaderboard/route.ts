import { leaderboardQuerySchema } from "@/lib/schemas";
import { authed, json, readQuery } from "@/server/api";
import { getLeaderboard } from "@/server/stats";
import { resolveTimeZone } from "@/server/timezone";

export const GET = authed(async ({ req, user }) => {
  const { metric, tz } = readQuery(req, leaderboardQuerySchema);
  return json(await getLeaderboard(user, metric, resolveTimeZone(tz)));
});
