import { authed, json } from "@/server/api";
import { listFriends } from "@/server/friends";

export const GET = authed(async ({ user }) => json(await listFriends(user.id)));
