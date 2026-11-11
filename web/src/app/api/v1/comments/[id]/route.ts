import { deleteComment } from "@/server/activities";
import { authed, noContent, uuidParam } from "@/server/api";

export const DELETE = authed(async ({ params, user }) => {
  await deleteComment(user.id, uuidParam(params.id));
  return noContent();
});
