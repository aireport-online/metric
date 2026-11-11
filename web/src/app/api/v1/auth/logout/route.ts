import { noContent, open } from "@/server/api";
import { deleteSession } from "@/server/auth";

export const POST = open(async ({ token }) => {
  await deleteSession(token);
  return noContent();
});
