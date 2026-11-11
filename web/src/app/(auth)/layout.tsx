import Link from "next/link";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { Track } from "@/components/track";
import { getSessionUser } from "@/server/session";

async function RedirectWhenLoggedIn() {
  if (await getSessionUser()) redirect("/feed");
  return null;
}

export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="column flex min-h-screen flex-col">
      <header className="flex h-16 flex-none items-center">
        <Link href="/" aria-label="Metric, naar de startpagina" className="press">
          <Logo />
        </Link>
      </header>
      {/* The form on the left; on a wide screen the empty track waits on the right. */}
      <div className="grid flex-1 items-start gap-x-16 pb-16 pt-10 max-sm:pt-4 lg:grid-cols-[420px_minmax(0,1fr)]">
        <main className="rise w-full max-w-[420px] max-lg:mx-auto">{children}</main>
        <div className="fade-in flex justify-center pt-14 max-lg:hidden" aria-hidden>
          <Track width={560} thickness={16} lanes={[{ progress: 1 }, { progress: 0.72 }, { progress: 0.45 }]} label="">
            <span className="figure-xl text-[52px]">
              Elke week
              <br />
              een ronde.
            </span>
          </Track>
        </div>
      </div>
      <Suspense>
        <RedirectWhenLoggedIn />
      </Suspense>
    </div>
  );
}
