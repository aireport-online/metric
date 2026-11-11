"use client";

import { useActionState, type ReactNode } from "react";
import type { FormState } from "@/server/form";

/**
 * A button that runs one server action (already bound to its target) and shows the error, if any,
 * next to itself.
 */
export function ActionButton({
  action,
  children,
  className = "btn btn-sm btn-outline",
  confirm,
}: {
  action: (prev: FormState) => Promise<FormState>;
  children: ReactNode;
  className?: string;
  confirm?: string;
}) {
  const [state, run, pending] = useActionState(action, undefined);
  return (
    <form action={run} className="flex items-center gap-2">
      <button
        type="submit"
        className={className}
        disabled={pending}
        onClick={(event) => {
          if (confirm && !window.confirm(confirm)) event.preventDefault();
        }}
      >
        {children}
      </button>
      {state?.error ? (
        <span role="alert" className="text-[12px] text-negative">
          {state.error}
        </span>
      ) : null}
    </form>
  );
}
