/**
 * The mark: a small m whose arches are the bends of a track, with the finish line at the foot of
 * the last leg. Below 32px the lane lines are left out (brand/logo/metric-mark-small-dark.svg).
 */
export function Mark({ height = 22, lines = false }: { height?: number; lines?: boolean }) {
  return (
    <svg height={height} width={(height * 448) / 324} viewBox="0 0 448 324" aria-hidden>
      <g transform="translate(-32 -96)">
        <path d="M80 420V232A88 88 0 0 1 256 232V420M256 232A88 88 0 0 1 432 232V420" fill="none" stroke="var(--accent)" strokeWidth="96" />
        {lines ? (
          <path
            d="M96 420V232A72 72 0 0 1 240 232V420M64 420V232A104 104 0 0 1 256 176.57M272 420V232A72 72 0 0 1 416 232V392M256 176.57A104 104 0 0 1 448 232V392"
            fill="none"
            stroke="var(--text)"
            strokeWidth="6"
          />
        ) : null}
        <rect x="384" y="392" width="96" height="28" fill="var(--volt)" />
      </g>
    </svg>
  );
}

/** Mark plus wordmark. The wordmark is set in the display face, as in the brand's lockup. */
export function Logo({ size = "md" }: { size?: "md" | "lg" }) {
  const large = size === "lg";
  return (
    <span className="flex items-center gap-2.5">
      <Mark height={large ? 40 : 24} lines={large} />
      <span className={`font-display font-extrabold italic leading-none tracking-[0.01em] ${large ? "text-[44px]" : "text-[26px]"}`}>METRIC</span>
    </span>
  );
}
