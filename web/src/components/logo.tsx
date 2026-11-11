/** Three rising measures; the last one, the running week, carries the hue. */
export function Mark({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" aria-hidden>
      <rect x="2" y="11" width="4" height="7" rx="1" fill="var(--text)" />
      <rect x="8" y="7" width="4" height="11" rx="1" fill="var(--text)" />
      <rect x="14" y="2" width="4" height="16" rx="1" fill="var(--hue)" />
    </svg>
  );
}

export function Logo() {
  return (
    <span className="flex items-center gap-2 text-[16px] font-bold tracking-[-0.01em]">
      <Mark />
      Metric
    </span>
  );
}
