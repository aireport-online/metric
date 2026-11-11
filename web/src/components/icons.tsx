import type { SVGProps } from "react";
import type { ActivityType } from "@/lib/constants";
import { sportColor } from "@/lib/sports";

const base = (props: SVGProps<SVGSVGElement>, size = 16) => ({
  width: size,
  height: size,
  viewBox: `0 0 ${size} ${size}`,
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.5,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
  ...props,
});

export const PlusIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)} strokeWidth={2}>
    <path d="M8 3v10M3 8h10" />
  </svg>
);
export const KudosIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M5 7.2 7.6 2.5c.9 0 1.6.8 1.4 1.7L8.6 6.5h3.2c.9 0 1.5.8 1.3 1.6l-.9 4.1c-.1.7-.7 1.1-1.3 1.1H5z" />
    <path d="M5 13.3H3.2c-.4 0-.7-.3-.7-.7V7.9c0-.4.3-.7.7-.7H5" />
  </svg>
);
export const CommentIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M13.5 9.8c0 .7-.6 1.2-1.2 1.2H5.6l-3.1 2.5V3.7c0-.7.5-1.2 1.2-1.2h8.6c.6 0 1.2.5 1.2 1.2z" />
  </svg>
);
export const LinkIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M6.8 9.2a2.8 2.8 0 0 0 4 0l2-2a2.8 2.8 0 0 0-4-4l-.6.6" />
    <path d="M9.2 6.8a2.8 2.8 0 0 0-4 0l-2 2a2.8 2.8 0 0 0 4 4l.6-.6" />
  </svg>
);

/* Navigation, on a 22px grid. */
export const FeedIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p, 22)} strokeWidth={1.75}>
    <rect x="3.5" y="3.5" width="15" height="6" rx="2" />
    <rect x="3.5" y="12.5" width="15" height="6" rx="2" />
  </svg>
);
/** Progress is the track itself. */
export const TrackIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p, 22)} strokeWidth={1.75}>
    <rect x="2.5" y="5.5" width="17" height="11" rx="5.5" />
    <path d="M8 16.5v-3" />
  </svg>
);
export const StopwatchIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p, 22)} strokeWidth={1.75}>
    <circle cx="11" cy="12.5" r="6.5" />
    <path d="M11 12.5V9M9 3h4M11 3v3" />
  </svg>
);
export const FriendsIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p, 22)} strokeWidth={1.75}>
    <circle cx="8" cy="8" r="3" />
    <path d="M2.5 18c0-3 2.5-5 5.5-5s5.5 2 5.5 5" />
    <path d="M14.5 5.3a3 3 0 0 1 0 5.4M16 13.3c2 .6 3.5 2.3 3.5 4.7" />
  </svg>
);

/* One pictogram per sport, on a 20px grid. */
const SPORT_PATHS: Record<ActivityType, React.ReactNode> = {
  run: <path d="M2.5 14.5h12a3 3 0 0 0 3-3c-2.8 0-4.8-1.4-6.2-3.8L9 9 7.5 6.5 4 7.5v4l-1.5 1zM2.5 14.5v1.5h15v-1.5" />,
  walk: (
    <>
      <path d="M6.5 3.5c1.5 0 2.5 1.5 2.5 3.5s-.5 3-.5 4-.8 1.5-2 1.5-2-.5-2-1.5-.5-2-.5-4 1-3.5 2.5-3.5zM4.5 14.5h4" />
      <path d="M13.5 7c1.5 0 2.5 1.5 2.5 3.5s-.5 3-.5 4-.8 1.5-2 1.5-2-.5-2-1.5-.5-2-.5-4 1-3.5 2.5-3.5z" />
    </>
  ),
  hike: <path d="M2 16.5 7.5 6.5l3 5 2.2-3.5 5.3 8.5zM5.8 9.6l1.7 1.4 1.6-1.6" />,
  ride: (
    <>
      <circle cx="5" cy="13" r="3.2" />
      <circle cx="15" cy="13" r="3.2" />
      <path d="M5 13l3-6.5h4.5L15 13M8 6.5 10.5 13M7 4.5h2.5M12.5 6.5l-.8-2h2" />
    </>
  ),
  swim: (
    <>
      <path d="M2 12.5c1.3-1.3 2.7-1.3 4 0s2.7 1.3 4 0 2.7-1.3 4 0 2.7 1.3 4 0M2 16.5c1.3-1.3 2.7-1.3 4 0s2.7 1.3 4 0 2.7-1.3 4 0 2.7 1.3 4 0" />
      <circle cx="14.5" cy="6.5" r="1.7" />
      <path d="M5.5 9.5 9 6l3 3" />
    </>
  ),
  strength: <path d="M2 8v4M5 5.5v9M15 5.5v9M18 8v4M5 10h10" />,
  hiit: <path d="M11.5 2 4.5 11.5h5l-1 6.5 7-9.5h-5z" />,
  yoga: (
    <>
      <circle cx="10" cy="4.5" r="2" />
      <path d="M3 16.5c2.5-.5 4.5-1 7-4.5 2.5 3.5 4.5 4 7 4.5M5 10l5 2 5-2" />
    </>
  ),
  rowing: (
    <>
      <path d="M5 15 14 4.5M14 4.5l3-1-1 3z" />
      <path d="M2 17c1.7-1 3.3-1 5 0M12 17c1.7-1 3.3-1 5 0" />
    </>
  ),
  football: (
    <>
      <circle cx="10" cy="10" r="7.5" />
      <path d="m10 6.5 3.3 2.4-1.3 3.9H8l-1.3-3.9zM10 6.5v-4M13.3 8.9l3.7-1.2M12 12.8l2.3 3.2M8 12.8 5.7 16M6.7 8.9 3 7.7" />
    </>
  ),
  tennis: (
    <>
      <circle cx="10" cy="10" r="7.5" />
      <path d="M4.7 4.7c3 2.5 3 8.1 0 10.6M15.3 4.7c-3 2.5-3 8.1 0 10.6" />
    </>
  ),
  other: (
    <>
      <circle cx="10" cy="11.5" r="6" />
      <path d="M10 11.5V8M8 2.5h4M10 2.5v3" />
    </>
  ),
};

/** The sport's pictogram in the sport's tint. Decorative: the sport is always named next to it. */
export function SportIcon({ type, size = 20, tinted = true }: { type: ActivityType; size?: number; tinted?: boolean }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 20 20"
      fill="none"
      stroke={tinted ? sportColor(type) : "currentColor"}
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className="flex-none"
    >
      {SPORT_PATHS[type]}
    </svg>
  );
}
