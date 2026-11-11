"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { CloseIcon, MenuIcon } from "./icons";
import { Avatar } from "./ui";

type NavUser = { username: string; displayName: string };

const LINKS = [
  { href: "/feed", label: "Feed" },
  { href: "/dashboard", label: "Voortgang" },
  { href: "/activities", label: "Activiteiten" },
  { href: "/friends", label: "Vrienden" },
];

const isActive = (pathname: string, href: string) => pathname === href || pathname.startsWith(`${href}/`);

export function Nav({ user, requests, logout }: { user: NavUser; requests: number; logout: () => Promise<void> }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // Close the sheet after navigating and keep the page behind it from scrolling.
  useEffect(() => setOpen(false), [pathname]);
  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  const badge = requests > 0 ? (
    <span className="num ml-1.5 rounded-full bg-primary px-1.5 text-[12px] leading-[18px] text-white" aria-label={`${requests} open verzoeken`}>
      {requests}
    </span>
  ) : null;

  return (
    <>
      <nav aria-label="Hoofdmenu" className="flex items-center gap-1 max-md:hidden">
        {LINKS.map((link) => {
          const active = isActive(pathname, link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              aria-current={active ? "page" : undefined}
              className={`flex h-8 items-center rounded-control px-3 font-medium transition-colors ${
                active ? "bg-raised text-ink" : "text-muted hover:text-ink"
              }`}
            >
              {link.label}
              {link.href === "/friends" ? badge : null}
            </Link>
          );
        })}
      </nav>

      <Link
        href="/settings"
        className="ml-auto flex h-8 items-center gap-2 rounded-control pl-1 pr-2.5 font-medium hover:bg-raised max-md:hidden"
        aria-current={isActive(pathname, "/settings") ? "page" : undefined}
      >
        <Avatar username={user.username} name={user.displayName} size={24} />
        {user.displayName}
      </Link>

      <button
        type="button"
        className="-mr-2 ml-auto flex h-11 w-11 items-center justify-center md:hidden"
        aria-expanded={open}
        aria-controls="menu-sheet"
        onClick={() => setOpen(true)}
      >
        <MenuIcon width={20} height={20} />
        <span className="sr-only">Menu openen</span>
        {requests > 0 ? <span className="absolute ml-5 -mt-4 h-2 w-2 rounded-full bg-primary" aria-hidden /> : null}
      </button>

      {open ? (
        <div id="menu-sheet" role="dialog" aria-modal="true" aria-label="Menu" className="fixed inset-0 z-50 flex flex-col bg-ground md:hidden">
          <div className="column flex h-12 flex-none items-center justify-between">
            <span className="flex items-center gap-2 font-medium">
              <Avatar username={user.username} name={user.displayName} size={24} />
              {user.displayName}
            </span>
            <button type="button" className="-mr-2 flex h-11 w-11 items-center justify-center" onClick={() => setOpen(false)}>
              <CloseIcon width={20} height={20} />
              <span className="sr-only">Menu sluiten</span>
            </button>
          </div>
          <nav aria-label="Hoofdmenu" className="column flex flex-col pt-2">
            {[...LINKS, { href: "/settings", label: "Instellingen" }].map((link) => (
              <Link
                key={link.href}
                href={link.href}
                aria-current={isActive(pathname, link.href) ? "page" : undefined}
                className="flex h-12 items-center border-b border-line text-[16px] font-medium"
              >
                {link.label}
                {link.href === "/friends" ? badge : null}
              </Link>
            ))}
            <form action={logout} className="pt-5">
              <button type="submit" className="btn btn-secondary w-full">
                Uitloggen
              </button>
            </form>
          </nav>
        </div>
      ) : null}
    </>
  );
}
