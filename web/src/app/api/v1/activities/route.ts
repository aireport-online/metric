import { activityInputSchema, pageQuerySchema } from "@/lib/schemas";
import { listOwnActivities, upsertActivity } from "@/server/activities";
import { authed, json, readBody, readQuery } from "@/server/api";

export const GET = authed(async ({ req, user }) =>
  json(await listOwnActivities(user.id, readQuery(req, pageQuerySchema(100, 30)))),
);

export const POST = authed(async ({ req, user }) => {
  const { activity, created } = await upsertActivity(user, await readBody(req, activityInputSchema));
  return json({ activity }, created ? 201 : 200);
});
