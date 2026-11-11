import type { Metadata, Viewport } from "next";
import "@fontsource/barlow-condensed/600.css";
import "@fontsource/barlow-condensed/700.css";
import "@fontsource/barlow-condensed/700-italic.css";
import "@fontsource/barlow-condensed/800-italic.css";
import "@fontsource/instrument-sans/400.css";
import "@fontsource/instrument-sans/500.css";
import "@fontsource/instrument-sans/600.css";
import { TimeZoneCookie } from "@/components/client-bits";
import "./globals.css";

const appUrl = (process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "");

export const metadata: Metadata = {
  metadataBase: new URL(appUrl),
  title: { default: "Metric – elke week een ronde", template: "%s · Metric" },
  description: "Houd je sportactiviteiten bij met iPhone en Apple Watch en deel je voortgang met vrienden.",
  openGraph: { siteName: "Metric", locale: "nl_NL" },
};

export const viewport: Viewport = { themeColor: "#0c0e11", colorScheme: "dark" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="nl" className="h-full antialiased">
      <body className="min-h-full font-sans">
        {children}
        <TimeZoneCookie />
      </body>
    </html>
  );
}
