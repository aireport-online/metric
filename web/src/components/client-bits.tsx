"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";
import { TZ_COOKIE } from "@/lib/constants";
import { LinkIcon } from "./icons";

/** Remembers the browser's time zone so the server can show dates and weeks in it. */
export function TimeZoneCookie() {
  useEffect(() => {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (zone && !document.cookie.includes(`${TZ_COOKIE}=${encodeURIComponent(zone)}`)) {
      document.cookie = `${TZ_COOKIE}=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`;
    }
  }, []);
  return null;
}

export function SubmitButton({
  children,
  className = "btn btn-primary",
  pendingLabel,
}: {
  children: ReactNode;
  className?: string;
  pendingLabel?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className={className} disabled={pending}>
      {pending && pendingLabel ? pendingLabel : children}
    </button>
  );
}

export function CopyButton({ value, label = "Kopieer link", className = "btn btn-outline" }: { value: string; label?: string; className?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className={className}
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          setTimeout(() => setCopied(false), 2000);
        } catch {
          window.prompt("Kopieer deze link:", value);
        }
      }}
    >
      <LinkIcon />
      <span aria-live="polite">{copied ? "Gekopieerd" : label}</span>
    </button>
  );
}

/** Submit button that first asks for confirmation; used for destructive actions. */
export function ConfirmSubmit({ children, message, className = "btn btn-danger" }: { children: ReactNode; message: string; className?: string }) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className={className}
      disabled={pending}
      onClick={(event) => {
        if (!window.confirm(message)) event.preventDefault();
      }}
    >
      {children}
    </button>
  );
}
