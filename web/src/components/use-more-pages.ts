"use client";

import { useState } from "react";

type Page<T> = { activities: T[]; nextCursor: string | null };

/**
 * A list whose first page comes from the server and whose later pages are fetched with "more".
 *
 * The first page is rendered straight from props, so fresh server data always shows; keeping it in
 * state would freeze the list at its first load, because Next keeps visited routes mounted. Only
 * the extra pages live in state. They are dropped when the first page's cursor changes, since they
 * no longer line up with it.
 */
export function useMorePages<T extends { id: string }>(initial: T[], initialCursor: string | null) {
  const [more, setMore] = useState<{ base: string | null; items: T[]; cursor: string | null } | null>(null);
  const extra = more && more.base === initialCursor ? more : null;

  const seen = new Set(initial.map((item) => item.id));
  const items = extra ? [...initial, ...extra.items.filter((item) => !seen.has(item.id))] : initial;
  const cursor = extra ? extra.cursor : initialCursor;

  const append = (page: Page<T>) =>
    setMore((current) => {
      const kept = current && current.base === initialCursor ? current.items : [];
      return { base: initialCursor, items: [...kept, ...page.activities], cursor: page.nextCursor };
    });

  return { items, cursor, append };
}
