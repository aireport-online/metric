import Link from "next/link";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { getSessionUser } from "@/server/session";

async function RedirectWhenLoggedIn() {
  if (await getSessionUser()) redirect("/feed");
  return null;
}

export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    // One centred column of 400px: the logo sits on the form's left edge.
    <div className="column flex min-h-screen flex-col">
      <header className="mx-auto flex h-12 w-full max-w-[400px] flex-none items-center">
        <Link href="/" aria-label="Metric, naar de startpagina">
          <Logo />
        </Link>
      </header>
      <main className="mx-auto w-full max-w-[400px] flex-1 pb-16 pt-12 max-sm:pt-6">{children}</main>
      <Suspense>
        <RedirectWhenLoggedIn />
      </Suspense>
    </div>
  );
}
