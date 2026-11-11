import { Suspense } from "react";
import { TopBar, TopBarFallback } from "@/components/top-bar";

export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="flex min-h-screen flex-col">
      {/* The bar reads the session, so it streams in; the page below has its own boundary. */}
      <Suspense fallback={<TopBarFallback />}>
        <TopBar />
      </Suspense>
      {/* On a phone the tab bar sits over the foot of the page, so the page ends above it. */}
      <main className="column flex-1 pb-16 max-md:pb-28">{children}</main>
    </div>
  );
}
