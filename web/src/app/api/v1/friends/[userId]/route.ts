import { authed, noContent, uuidParam } from "@/server/api";
import { removeFriend } from "@/server/friends";

export const DELETE = authed(async ({ params, user }) => {
  await removeFriend(user.id, uuidParam(params.userId));
  return noContent();
});
