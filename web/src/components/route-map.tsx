import type { CSSProperties } from "react";

type Point = [number, number];

/**
 * Equirectangular projection, with longitudes scaled by cos(latitude) so distances east-west
 * are in proportion to north-south. Good enough for anything a person runs or rides in a day.
 */
function project(route: Point[], width: number, height: number, pad: number) {
  const lats = route.map((p) => p[0]);
  const lons = route.map((p) => p[1]);
  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLon = Math.min(...lons);
  const maxLon = Math.max(...lons);
  const k = Math.cos((((minLat + maxLat) / 2) * Math.PI) / 180);
  const spanX = Math.max((maxLon - minLon) * k, 1e-9);
  const spanY = Math.max(maxLat - minLat, 1e-9);
  const scale = Math.min((width - 2 * pad) / spanX, (height - 2 * pad) / spanY);
  const offsetX = (width - spanX * scale) / 2;
  const offsetY = (height - spanY * scale) / 2;
  const points = route.map(([lat, lon]): Point => [
    offsetX + (lon - minLon) * k * scale,
    offsetY + (maxLat - lat) * scale,
  ]);
  // One degree of latitude is about 111.32 km.
  return { points, pixelsPerMeter: scale / 111_320 };
}

const SCALE_STEPS = [50, 100, 200, 500, 1000, 2000, 5000, 10_000, 20_000, 50_000, 100_000];

/** Length of the drawn line in viewBox units, so the line can run out from its start. */
function lengthOf(points: Point[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) total += Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]);
  return total;
}

export function RouteMap({ route, label, color = "var(--accent)" }: { route: Point[]; label: string; color?: string }) {
  const width = 720;
  const height = 360;
  const { points, pixelsPerMeter } = project(route, width, height, 32);
  const d = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join("");
  const length = Math.ceil(lengthOf(points)) + 1;
  const meters = [...SCALE_STEPS].reverse().find((step) => step * pixelsPerMeter <= width * 0.25) ?? SCALE_STEPS[0];
  const at = ([x, y]: Point) => ({ left: `${(x / width) * 100}%`, top: `${(y / height) * 100}%` });

  // The line draws itself from start to finish. The markers and the scale bar are laid over it in
  // HTML so they keep their size and stay readable on a phone.
  return (
    <div role="img" aria-label={label} className="relative overflow-hidden rounded-control bg-raised">
      <svg viewBox={`0 0 ${width} ${height}`} aria-hidden className="block h-auto w-full">
        <path d={d} fill="none" stroke="var(--line-strong)" strokeWidth="5" strokeLinejoin="round" strokeLinecap="round" />
        <path
          d={d}
          fill="none"
          stroke={color}
          strokeWidth="5"
          strokeLinejoin="round"
          strokeLinecap="round"
          strokeDasharray={`${length} ${length * 2}`}
          className="lap"
          style={{ "--lap-from": length + 8, animationDuration: "1400ms" } as CSSProperties}
        />
      </svg>
      <span className="absolute h-3.5 w-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full border-[3px] border-ink bg-raised" style={at(points[0])} />
      <span
        className="fade-in absolute h-3.5 w-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-volt ring-[3px] ring-raised"
        style={{ ...at(points[points.length - 1]), animationDelay: "900ms" }}
      />
      <div className="absolute bottom-3 left-3 flex items-end gap-1.5 text-[14px] leading-none text-muted" style={{ right: 12 }}>
        <span className="h-1.5 border-x border-b border-muted" style={{ width: `${((meters * pixelsPerMeter) / width) * 100}%` }} />
        <span className="num">{meters >= 1000 ? `${meters / 1000} km` : `${meters} m`}</span>
      </div>
    </div>
  );
}

/** Small outline of the route for lists, in chalk; tartan stays on the screen's main figure. */
export function RouteThumb({ route }: { route: Point[] }) {
  const { points } = project(route, 96, 72, 9);
  const d = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join("");
  return (
    <svg width="96" height="72" viewBox="0 0 96 72" aria-hidden className="flex-none rounded-control bg-raised max-[420px]:h-[54px] max-[420px]:w-[72px]">
      <path d={d} fill="none" stroke="var(--text)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}
