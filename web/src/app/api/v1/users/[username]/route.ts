import { getProfile } from "@/server/activities";
import { json, open } from "@/server/api";

export const GET = open(async ({ params, user }) => json(await getProfile(user?.id ?? null, params.username)));
