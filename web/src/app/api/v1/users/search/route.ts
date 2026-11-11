import { authed, json } from "@/server/api";
import { searchUsers } from "@/server/friends";

export const GET = authed(async ({ req, user }) =>
  json({ users: await searchUsers(user.id, req.nextUrl.searchParams.get("q") ?? "") }),
);
