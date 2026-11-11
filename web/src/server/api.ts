import { unstable_rethrow } from "next/navigation";
import { NextResponse, type NextRequest } from "next/server";
import { z, ZodError } from "zod";
import { SESSION_COOKIE } from "@/lib/constants";
import { getUserForToken } from "./auth";
import type { UserRow } from "./db/schema";
import { ApiError, notFound, unauthorized } from "./errors";

type Params = Record<string, string>;
type Context<U> = { req: NextRequest; params: Params; user: U; token: string | null };
type Handler<U> = (context: Context<U>) => Promise<Response>;
type RouteArgs = { params: Promise<Params> };

export const json = (data: unknown, status = 200) => NextResponse.json(data, { status });
export const noContent = () => new NextResponse(null, { status: 204 });

export function errorResponse(error: unknown): Response {
  if (error instanceof ApiError) {
    return json({ error: { code: error.code, message: error.message } }, error.status);
  }
  if (error instanceof ZodError) {
    const issue = error.issues[0];
    const field = issue?.path.join(".");
    const message = issue ? (field ? `${field}: ${issue.message}` : issue.message) : "Ongeldige invoer.";
    return json({ error: { code: "invalid_request", message } }, 400);
  }
  console.error(error);
  return json({ error: { code: "internal_error", message: "Er ging iets mis op de server." } }, 500);
}

function tokenFrom(req: NextRequest): string | null {
  const header = req.headers.get("authorization");
  if (header?.toLowerCase().startsWith("bearer ")) return header.slice(7).trim() || null;
  return req.cookies.get(SESSION_COOKIE)?.value ?? null;
}

function wrap<U>(resolveUser: (user: UserRow | null) => U, handler: Handler<U>) {
  return async (req: NextRequest, args: RouteArgs): Promise<Response> => {
    try {
      const token = tokenFrom(req);
      const user = resolveUser(await getUserForToken(token));
      return await handler({ req, params: await args.params, user, token });
    } catch (error) {
      // Next's own control-flow errors (such as the signal that a route reads the request and
      // cannot be prerendered) must reach the framework untouched.
      unstable_rethrow(error);
      return errorResponse(error);
    }
  };
}

/** Route that needs a logged-in user. */
export const authed = (handler: Handler<UserRow>) =>
  wrap((user) => {
    if (!user) throw unauthorized();
    return user;
  }, handler);

/** Route that also works without login; `user` is null then. */
export const open = (handler: Handler<UserRow | null>) => wrap((user) => user, handler);

export async function readBody<T extends z.ZodType>(req: NextRequest, schema: T): Promise<z.infer<T>> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    throw new ApiError(400, "invalid_request", "De aanvraag bevat geen geldige JSON.");
  }
  return schema.parse(body);
}

export function readQuery<T extends z.ZodType>(req: NextRequest, schema: T): z.infer<T> {
  return schema.parse(Object.fromEntries(req.nextUrl.searchParams));
}

/** Path parameters that must be UUIDs; anything else cannot exist, so it is a 404. */
export function uuidParam(value: string | undefined): string {
  const parsed = z.guid().safeParse(value);
  if (!parsed.success) throw notFound();
  return parsed.data.toLowerCase();
}

export function clientIp(req: NextRequest): string {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}
