import type { CSSProperties, ReactNode } from "react";

export type Lane = {
  /** Share of the lap that is run: 0–1, and above 1 once the goal is passed. */
  progress: number;
  /** CSS colour of the filled part. The outer lane defaults to tartan, inner lanes to chalk. */
  color?: string;
};

const LANE_GAP = 3;
const DEFAULT_COLORS = ["var(--accent)", "var(--text)", "var(--text-secondary)"];

/** One lane: from the start line on the lower straight, anticlockwise round the stadium. */
function lanePath(width: number, height: number, d: number): string {
  const r = height / 2 - d;
  const left = height / 2;
  const right = width - height / 2;
  return `M${left} ${height - d}H${right}A${r} ${r} 0 0 0 ${right} ${d}H${left}A${r} ${r} 0 0 0 ${left} ${height - d}`;
}

/**
 * The track: progress as lanes round a stadium shape instead of a ring. Up to three lanes, each
 * running out from the start line; once the outer lane is full the finish mark turns volt, and a
 * second lap in volt runs over the first for whatever is above the goal.
 *
 * The lap is a CSS animation that ends in the drawn state, so the track is complete without
 * JavaScript and with reduced motion.
 */
export function Track({
  lanes,
  width = 320,
  aspect = 2,
  thickness = 10,
  label,
  children,
  className = "",
  fixed = false,
}: {
  lanes: Lane[];
  /** Width of the drawing in px; it scales down with its container. */
  width?: number;
  aspect?: number;
  thickness?: number;
  /** What the track says, for screen readers. */
  label: string;
  /** Keep the drawing at exactly `width` px (small tracks in rows) instead of filling its container. */
  fixed?: boolean;
  /** Sits in the infield: the figure the track is about. */
  children?: ReactNode;
  className?: string;
}) {
  const height = width / aspect;
  const shown = lanes.slice(0, 3);
  const reached = shown[0] ? shown[0].progress >= 1 : false;
  const markX = height / 2;
  const depth = shown.length * thickness + (shown.length - 1) * LANE_GAP;

  return (
    <div className={`relative ${className}`} style={fixed ? { width } : { width: "100%", maxWidth: width }} role="img" aria-label={label}>
      <svg viewBox={`0 -5 ${width} ${height + 10}`} className="block h-auto w-full overflow-visible" aria-hidden>
        {shown.map((lane, i) => {
          const d = thickness / 2 + i * (thickness + LANE_GAP);
          const path = lanePath(width, height, d);
          const first = Math.max(0, Math.min(lane.progress, 1)) * 100;
          const second = Math.max(0, Math.min(lane.progress - 1, 1)) * 100;
          return (
            <g key={i} fill="none" strokeWidth={thickness} strokeLinecap="round">
              <path d={path} stroke="var(--line)" />
              {first > 0 ? (
                <path
                  d={path}
                  pathLength={100}
                  stroke={lane.color ?? DEFAULT_COLORS[i]}
                  strokeDasharray={`${first} 200`}
                  className="lap"
                  style={{ "--lap-from": first + 8, "--lane": i } as CSSProperties}
                />
              ) : null}
              {second > 0 ? (
                <path
                  d={path}
                  pathLength={100}
                  stroke="var(--volt)"
                  strokeDasharray={`${second} 200`}
                  className="lap"
                  style={{ "--lap-from": second + 8, "--lane": i, "--lap-delay": "500ms" } as CSSProperties}
                />
              ) : null}
            </g>
          );
        })}
        {/* Start and finish: a short line across the lanes on the lower straight. */}
        <line
          x1={markX}
          x2={markX}
          y1={height - depth - 4}
          y2={height + 4}
          strokeWidth={3}
          strokeLinecap="round"
          stroke={reached ? "var(--volt)" : "var(--text)"}
          className={reached ? "finish-reached" : undefined}
        />
      </svg>
      {children ? <div className="absolute inset-0 flex flex-col items-center justify-center text-center">{children}</div> : null}
    </div>
  );
}
