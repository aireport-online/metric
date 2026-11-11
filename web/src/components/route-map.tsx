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

export function RouteMap({ route, label }: { route: Point[]; label: string }) {
  const width = 720;
  const height = 360;
  const { points, pixelsPerMeter } = project(route, width, height, 28);
  const d = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join("");
  const [startX, startY] = points[0];
  const [endX, endY] = points[points.length - 1];
  const meters = [...SCALE_STEPS].reverse().find((step) => step * pixelsPerMeter <= width * 0.25) ?? SCALE_STEPS[0];
  const barWidth = meters * pixelsPerMeter;

  return (
    <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label={label} className="block h-auto w-full rounded-control bg-[#f4f4f4]">
      <path d={d} fill="none" stroke="var(--hue)" strokeWidth="3" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={startX} cy={startY} r="5" fill="var(--surface)" stroke="var(--text)" strokeWidth="2" />
      <circle cx={endX} cy={endY} r="5" fill="var(--text)" stroke="var(--surface)" strokeWidth="2" />
      <g transform={`translate(16 ${height - 16})`}>
        <path d={`M0 -5V0H${barWidth.toFixed(1)}V-5`} fill="none" stroke="var(--muted)" strokeWidth="1" />
        <text x={barWidth + 6} y="0" fontSize="12" fill="var(--muted)">
          {meters >= 1000 ? `${meters / 1000} km` : `${meters} m`}
        </text>
      </g>
    </svg>
  );
}

/** Small outline of the route for lists; drawn in ink so the hue stays on the screen's main figure. */
export function RouteThumb({ route }: { route: Point[] }) {
  const { points } = project(route, 96, 72, 8);
  const d = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`).join("");
  return (
    <svg width="96" height="72" viewBox="0 0 96 72" aria-hidden className="flex-none rounded-control bg-[#f4f4f4]">
      <path d={d} fill="none" stroke="var(--text)" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}
