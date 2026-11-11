import type { ReactNode } from "react";
import { initialOf, personHue } from "@/lib/format";

/** A person: their initial on a pale tint of their own hue. Identity, not data. */
export function Avatar({ username, name, size = 32 }: { username: string; name: string; size?: number }) {
  const hue = personHue(username);
  return (
    <span
      aria-hidden
      className="inline-flex flex-none items-center justify-center rounded-full font-medium"
      style={{
        width: size,
        height: size,
        fontSize: Math.max(11, Math.round(size * 0.42)),
        background: `hsl(${hue} 55% 91%)`,
        color: `hsl(${hue} 45% 24%)`,
      }}
    >
      {initialOf(name)}
    </span>
  );
}

export function PageTitle({ title, sub, action }: { title: ReactNode; sub?: ReactNode; action?: ReactNode }) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 pb-6 pt-8 max-sm:pt-5">
      <div className="min-w-0">
        <h1 className="text-[24px] font-bold leading-8 tracking-[-0.01em]">{title}</h1>
        {sub ? <p className="mt-1 text-muted">{sub}</p> : null}
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
        <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 px-5 pt-4">
          <h2 className="whitespace-nowrap text-[16px] font-medium leading-6">{title}</h2>
          {aside ? <div className="max-w-full flex-none text-muted">{aside}</div> : null}
        </div>
      ) : null}
      <div className={flush ? "" : "p-5 pt-3"}>{children}</div>
    </section>
  );
}

/** Keeps the frame of an empty block and says what will appear there. */
export function Empty({ children }: { children: ReactNode }) {
  return (
    <p className="rounded-control border border-dashed border-control px-4 py-3 text-muted">{children}</p>
  );
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

/** One figure with its label above and the unit as a smaller grey suffix. */
export function Figure({ label, value, unit }: { label: string; value: ReactNode; unit?: string }) {
  return (
    <div className="min-w-0">
      <div className="text-[12px] leading-4 text-muted">{label}</div>
      <div className="num mt-0.5 text-[16px] leading-6">
        {value}
        {unit ? <span className="ml-1 text-[12px] text-muted">{unit}</span> : null}
      </div>
    </div>
  );
}
