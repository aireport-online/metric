"use client";

import { useEffect, useRef } from "react";

type Format = "int" | "decimal1" | "decimal2" | "clock";

const formatters: Record<Format, (value: number) => string> = {
  int: (value) => new Intl.NumberFormat("nl-NL", { maximumFractionDigits: 0 }).format(Math.round(value)),
  decimal1: (value) => new Intl.NumberFormat("nl-NL", { minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(value),
  decimal2: (value) => new Intl.NumberFormat("nl-NL", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value),
  // seconds → 37:57 or 1:02:03
  clock: (value) => {
    const s = Math.round(value);
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const rest = String(s % 60).padStart(2, "0");
    return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${rest}` : `${m}:${rest}`;
  },
};

const DURATION = 800;
// The brand's "sprint" curve is close to an exponential ease-out.
const sprint = (t: number) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));

/**
 * A figure that counts up to its value while the track fills. The server renders the final value,
 * so the number is right without JavaScript; with reduced motion it simply stays there.
 */
export function CountUp({ value, format = "int", className }: { value: number; format?: Format; className?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const shown = useRef(0);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    const render = formatters[format];
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      node.textContent = render(value);
      shown.current = value;
      return;
    }
    // Counts from zero on arrival, and from the previous value when the figure changes.
    const from = shown.current === value ? 0 : shown.current;
    const started = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const t = Math.min((now - started) / DURATION, 1);
      node.textContent = render(from + (value - from) * sprint(t));
      if (t < 1) frame = requestAnimationFrame(tick);
      else shown.current = value;
    };
    node.textContent = render(from);
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      // Leave the true value behind if the animation is cut short (route hidden, unmount).
      node.textContent = render(value);
      shown.current = value;
    };
  }, [value, format]);

  return (
    <span ref={ref} className={className} suppressHydrationWarning>
      {formatters[format](value)}
    </span>
  );
}
