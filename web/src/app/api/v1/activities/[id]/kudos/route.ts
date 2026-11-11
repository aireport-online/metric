import { setKudos } from "@/server/activities";
import { authed, json, uuidParam } from "@/server/api";

export const POST = authed(async ({ params, user }) => json(await setKudos(user.id, uuidParam(params.id), true)));

export const DELETE = authed(async ({ params, user }) => json(await setKudos(user.id, uuidParam(params.id), false)));
