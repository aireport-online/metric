import { pageQuerySchema } from "@/lib/schemas";
import { listFeed } from "@/server/activities";
import { authed, json, readQuery } from "@/server/api";

export const GET = authed(async ({ req, user }) => json(await listFeed(user.id, readQuery(req, pageQuerySchema(50, 20)))));
