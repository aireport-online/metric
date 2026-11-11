import { loginSchema } from "@/lib/schemas";
import { clientIp, json, open, readBody } from "@/server/api";
import { authenticate, createSession } from "@/server/auth";
import { rateLimit } from "@/server/rate-limit";
import { toMe } from "@/server/serialize";

export const POST = open(async ({ req }) => {
  const input = await readBody(req, loginSchema);
  rateLimit(`login:${clientIp(req)}:${input.email}`, 10, 15 * 60 * 1000);
  const user = await authenticate(input);
  const { token } = await createSession(user.id, "app");
  return json({ token, user: toMe(user) });
});
