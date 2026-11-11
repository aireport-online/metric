import type { Metadata, Viewport } from "next";
import { GeistSans } from "geist/font/sans";
import { TimeZoneCookie } from "@/components/client-bits";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "Metric", template: "%s · Metric" },
  description: "Houd je sportactiviteiten bij met iPhone en Apple Watch en deel je voortgang met vrienden.",
};

export const viewport: Viewport = { themeColor: "#f8f8f8" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="nl" className={`${GeistSans.variable} h-full antialiased`}>
      <body className="min-h-full font-sans">
        {children}
        <TimeZoneCookie />
      </body>
    </html>
  );
}
