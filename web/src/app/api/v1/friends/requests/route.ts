import { friendRequestSchema } from "@/lib/schemas";
import { authed, json, readBody } from "@/server/api";
import { sendFriendRequest } from "@/server/friends";

export const POST = authed(async ({ req, user }) => {
  const { username } = await readBody(req, friendRequestSchema);
  return json({ status: await sendFriendRequest(user, username) }, 201);
});
