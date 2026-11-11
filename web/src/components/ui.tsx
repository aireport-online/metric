import type { ReactNode } from "react";
import { initialOf } from "@/lib/format";

/** A person: their initial as a lane number on a raised disc. Identity, not data. */
export function Avatar({ name, size = 32 }: { username?: string; name: string; size?: number }) {
  return (
    <span
      aria-hidden
      className="inline-flex flex-none items-center justify-center rounded-full bg-raised font-display font-bold text-ink"
      style={{ width: size, height: size, fontSize: Math.max(13, Math.round(size * 0.5)), lineHeight: 1 }}
    >
      {initialOf(name)}
    </span>
  );
}

export function PageTitle({ title, sub, action }: { title: ReactNode; sub?: ReactNode; action?: ReactNode }) {
  return (
    <header className="rise flex flex-wrap items-end justify-between gap-x-6 gap-y-4 pb-6 pt-8 max-sm:pt-5">
      <div className="min-w-0">
        <h1 className="display text-[44px] leading-[1.05] max-sm:text-[34px]">{title}</h1>
        {sub ? <p className="mt-1.5 text-muted">{sub}</p> : null}
      </div>
      {action ? <div className="flex max-w-full flex-wrap items-center gap-2">{action}</div> : null}
    </header>
  );
}

export function Panel({
  title,
  aside,
  children,
  className = "",
  flush = false,
}: {
  title?: ReactNode;
  aside?: ReactNode;
  children: ReactNode;
  className?: string;
  flush?: boolean;
}) {
  return (
    <section className={`panel ${className}`}>
      {title ? (
        <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 px-6 pt-5 max-sm:px-5">
          <h2 className="display whitespace-nowrap text-[24px] leading-[1.1]">{title}</h2>
          {aside ? <div className="max-w-full flex-none text-[14px] text-muted">{aside}</div> : null}
        </div>
      ) : null}
      <div className={flush ? "" : "p-6 pt-4 max-sm:p-5 max-sm:pt-4"}>{children}</div>
    </section>
  );
}

/** Keeps the frame of an empty block and gives the first step. */
export function Empty({ children }: { children: ReactNode }) {
  return <p className="rounded-control bg-raised px-4 py-3.5 text-muted">{children}</p>;
}

export function FormMessage({ state }: { state: { error?: string; ok?: boolean } | undefined }) {
  if (state?.error) {
    return (
      <p role="alert" className="text-negative">
        {state.error}
      </p>
    );
  }
  return null;
}

/** One figure: the number in the display italic, its unit small beside it, the label underneath. */
export function Figure({ label, value, unit, size = "md" }: { label: string; value: ReactNode; unit?: string; size?: "md" | "lg" }) {
  return (
    <div className="min-w-0">
      <div className={`figure whitespace-nowrap ${size === "lg" ? "text-[56px] max-sm:text-[40px]" : "text-[32px]"}`}>
        {value}
        {unit ? <span className="figure-label ml-1 not-italic text-quiet">{unit}</span> : null}
      </div>
      <div className="figure-label mt-1 text-muted">{label}</div>
    </div>
  );
}
