import { activityBatchSchema } from "@/lib/schemas";
import { upsertActivities } from "@/server/activities";
import { authed, json, readBody } from "@/server/api";

export const POST = authed(async ({ req, user }) => {
  const { activities } = await readBody(req, activityBatchSchema);
  return json({ activities: await upsertActivities(user, activities) });
});
