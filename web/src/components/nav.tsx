"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { FeedIcon, FriendsIcon, StopwatchIcon, TrackIcon } from "./icons";
import { Avatar } from "./ui";

type NavUser = { username: string; displayName: string };

const LINKS = [
  { href: "/feed", label: "Feed", Icon: FeedIcon },
  { href: "/dashboard", label: "Voortgang", Icon: TrackIcon },
  { href: "/activities", label: "Activiteiten", Icon: StopwatchIcon },
  { href: "/friends", label: "Vrienden", Icon: FriendsIcon },
];

const isActive = (pathname: string, href: string) => pathname === href || pathname.startsWith(`${href}/`);

/**
 * Desktop: links in the top bar, the current one underlined by a tartan lane. Phone: the same four
 * destinations as a tab bar at the bottom of the screen, within reach of a thumb.
 */
export function Nav({ user, requests }: { user: NavUser; requests: number }) {
  const pathname = usePathname();

  const badge =
    requests > 0 ? (
      <span className="num ml-1.5 rounded-full bg-accent px-1.5 text-[13px] font-semibold leading-[20px] text-on-accent" aria-label={`${requests} open verzoeken`}>
        {requests}
      </span>
    ) : null;

  return (
    <>
      <nav aria-label="Hoofdmenu" className="flex items-center gap-1 self-stretch max-md:hidden">
        {LINKS.map((link) => {
          const active = isActive(pathname, link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              aria-current={active ? "page" : undefined}
              className={`relative flex items-center px-3.5 font-medium transition-colors duration-200 ${active ? "text-ink" : "text-muted hover:text-ink"}`}
            >
              {link.label}
              {link.href === "/friends" ? badge : null}
              {active ? <span aria-hidden className="grow-x absolute inset-x-3.5 bottom-0 h-[3px] rounded-full bg-accent" style={{ animationDuration: "320ms" }} /> : null}
            </Link>
          );
        })}
      </nav>

      <Link
        href="/settings"
        className="press ml-auto flex h-10 items-center gap-2.5 rounded-full pl-1 pr-4 font-medium hover:bg-raised max-lg:pr-1"
        aria-current={isActive(pathname, "/settings") ? "page" : undefined}
      >
        <Avatar name={user.displayName} size={32} />
        <span className="whitespace-nowrap max-lg:sr-only">{user.displayName}</span>
      </Link>

      <nav
        aria-label="Hoofdmenu"
        className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-4 border-t border-line bg-ground pb-[env(safe-area-inset-bottom)] md:hidden"
      >
        {LINKS.map(({ href, label, Icon }) => {
          const active = isActive(pathname, href);
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className={`press relative flex h-16 flex-col items-center justify-center gap-1 text-[12px] font-medium ${active ? "text-ink" : "text-quiet"}`}
            >
              {active ? <span aria-hidden className="grow-x absolute inset-x-6 top-0 h-[3px] rounded-full bg-accent" style={{ animationDuration: "320ms", transformOrigin: "center" }} /> : null}
              <span className="relative">
                <Icon className={active ? "text-accent" : undefined} />
                {href === "/friends" && requests > 0 ? <span className="absolute -right-1.5 -top-1 h-2.5 w-2.5 rounded-full bg-accent ring-2 ring-ground" aria-hidden /> : null}
              </span>
              {label}
              {href === "/friends" && requests > 0 ? <span className="sr-only"> ({requests} open verzoeken)</span> : null}
            </Link>
          );
        })}
      </nav>
    </>
  );
}
