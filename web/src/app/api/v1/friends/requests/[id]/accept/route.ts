import { authed, json, uuidParam } from "@/server/api";
import { acceptFriendRequest } from "@/server/friends";

export const POST = authed(async ({ params, user }) => {
  await acceptFriendRequest(user.id, uuidParam(params.id));
  return json({ status: "friends" });
});
