import { authed, noContent, uuidParam } from "@/server/api";
import { deleteFriendRequest } from "@/server/friends";

export const DELETE = authed(async ({ params, user }) => {
  await deleteFriendRequest(user.id, uuidParam(params.id));
  return noContent();
});
