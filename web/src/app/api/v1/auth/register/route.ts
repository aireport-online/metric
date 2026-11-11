import { registerSchema } from "@/lib/schemas";
import { clientIp, json, open, readBody } from "@/server/api";
import { createSession, registerUser } from "@/server/auth";
import { rateLimit } from "@/server/rate-limit";
import { toMe } from "@/server/serialize";

export const POST = open(async ({ req }) => {
  rateLimit(`register:${clientIp(req)}`, 10, 60 * 60 * 1000);
  const user = await registerUser(await readBody(req, registerSchema));
  const { token } = await createSession(user.id, "app");
  return json({ token, user: toMe(user) }, 201);
});
