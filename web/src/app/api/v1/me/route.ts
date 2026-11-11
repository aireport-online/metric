import { deleteMeSchema, updateMeSchema } from "@/lib/schemas";
import { authed, json, noContent, readBody } from "@/server/api";
import { deleteUser, updateUser } from "@/server/auth";
import { toMe } from "@/server/serialize";

export const GET = authed(async ({ user }) => json({ user: toMe(user) }));

export const PATCH = authed(async ({ req, user }) => {
  const updated = await updateUser(user.id, await readBody(req, updateMeSchema));
  return json({ user: toMe(updated) });
});

export const DELETE = authed(async ({ req, user }) => {
  const { password } = await readBody(req, deleteMeSchema);
  await deleteUser(user, password);
  return noContent();
});
