import { statsQuerySchema } from "@/lib/schemas";
import { authed, json, readQuery } from "@/server/api";
import { getStats } from "@/server/stats";
import { resolveTimeZone } from "@/server/timezone";

export const GET = authed(async ({ req, user }) => {
  const { weeks, tz } = readQuery(req, statsQuerySchema);
  return json(await getStats(user, weeks, resolveTimeZone(tz)));
});
