import type { SVGProps } from "react";

const base = (props: SVGProps<SVGSVGElement>) => ({
  width: 16,
  height: 16,
  viewBox: "0 0 16 16",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.5,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
  ...props,
});

export const MenuIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M2.5 4.5h11M2.5 8h11M2.5 11.5h11" />
  </svg>
);
export const CloseIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M3.5 3.5l9 9M12.5 3.5l-9 9" />
  </svg>
);
export const PlusIcon = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
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
