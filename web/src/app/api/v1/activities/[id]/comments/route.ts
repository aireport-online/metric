import { commentSchema } from "@/lib/schemas";
import { addComment } from "@/server/activities";
import { authed, json, readBody, uuidParam } from "@/server/api";

export const POST = authed(async ({ req, params, user }) => {
  const { body } = await readBody(req, commentSchema);
  return json({ comment: await addComment(user, uuidParam(params.id), body) }, 201);
});
