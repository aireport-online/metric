import { ViewTransition } from "react";

/**
 * Route change inside the app: the page that leaves fades out quickly and the next one fades in,
 * with its own cards rising underneath. Browsers without view transitions simply swap the pages.
 */
export default function AppTemplate({ children }: { children: React.ReactNode }) {
  return (
    <ViewTransition enter="page-in" exit="page-out" default="none">
      {children}
    </ViewTransition>
  );
}
