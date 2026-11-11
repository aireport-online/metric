import { NextResponse, type NextRequest } from "next/server";
import { SESSION_COOKIE } from "@/lib/constants";

// Optimistic check only: it looks at whether a session cookie exists, not whether it is valid.
// Every page and action still verifies the session against the database.
const PROTECTED = ["/feed", "/dashboard", "/friends", "/settings"];

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const hasSession = request.cookies.has(SESSION_COOKIE);

  if (pathname === "/" && hasSession) {
    return NextResponse.redirect(new URL("/feed", request.url));
  }
  const needsLogin =
    PROTECTED.some((path) => pathname === path || pathname.startsWith(`${path}/`)) ||
    pathname === "/activities" ||
    pathname === "/activities/new";
  if (needsLogin && !hasSession) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/", "/feed/:path*", "/dashboard/:path*", "/friends/:path*", "/settings/:path*", "/activities", "/activities/new"],
};
