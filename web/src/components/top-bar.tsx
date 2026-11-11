import Link from "next/link";
import { logoutAction } from "@/app/actions/auth";
import { listFriends } from "@/server/friends";
import { getSessionUser } from "@/server/session";
import { Logo } from "./logo";
import { Nav } from "./nav";

export async function TopBar() {
  const user = await getSessionUser();
  const requests = user ? (await listFriends(user.id)).incoming.length : 0;
  return (
    <header className="column relative flex h-12 items-center gap-6">
      <Link href={user ? "/feed" : "/"} aria-label="Metric, naar de startpagina">
        <Logo />
      </Link>
      {user ? (
        <Nav user={{ username: user.username, displayName: user.displayName }} requests={requests} logout={logoutAction} />
      ) : (
        <div className="ml-auto flex items-center gap-2">
          <Link href="/login" className="btn btn-secondary btn-sm">
            Inloggen
          </Link>
          <Link href="/register" className="btn btn-primary btn-sm">
            Registreren
          </Link>
        </div>
      )}
    </header>
  );
}

/** Shown while the session is being read: the bar keeps its height and the product keeps its name. */
export function TopBarFallback() {
  return (
    <header className="column flex h-12 items-center">
      <Logo />
    </header>
  );
}
