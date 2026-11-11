import { ZodError } from "zod";
import { ApiError } from "./errors";

export type FormState =
  | {
      error?: string;
      ok?: boolean;
      /** What was submitted, so a rejected form can be shown again as the person filled it in. */
      values?: Record<string, string>;
      /** Changes on every result; forms use it as their key to pick up fresh default values. */
      nonce?: number;
    }
  | undefined;

function submitted(form?: FormData): Record<string, string> | undefined {
  if (!form) return undefined;
  const values: Record<string, string> = {};
  for (const [name, value] of form) {
    // Passwords are never sent back to the browser.
    if (typeof value === "string" && !name.toLowerCase().includes("password") && !name.startsWith("$")) {
      values[name] = value;
    }
  }
  return values;
}

/** Turns an expected failure into a message for the form; anything else is a bug and is rethrown. */
export function formError(error: unknown, form?: FormData): NonNullable<FormState> {
  let message: string;
  if (error instanceof ApiError) message = error.message;
  else if (error instanceof ZodError) message = error.issues[0]?.message ?? "Controleer je invoer.";
  else throw error;
  return { error: message, values: submitted(form), nonce: Date.now() };
}

export const formOk = (): NonNullable<FormState> => ({ ok: true, nonce: Date.now() });
