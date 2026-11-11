import { activityPatchSchema } from "@/lib/schemas";
import { deleteActivity, getActivityDetail, updateActivity } from "@/server/activities";
import { authed, json, noContent, open, readBody, uuidParam } from "@/server/api";

export const GET = open(async ({ params, user }) =>
  json(await getActivityDetail(user?.id ?? null, uuidParam(params.id))),
);

export const PATCH = authed(async ({ req, params, user }) => {
  const patch = await readBody(req, activityPatchSchema);
  return json({ activity: await updateActivity(user.id, uuidParam(params.id), patch) });
});

export const DELETE = authed(async ({ params, user }) => {
  await deleteActivity(user.id, uuidParam(params.id));
  return noContent();
});
