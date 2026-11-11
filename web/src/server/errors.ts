export type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "invalid_credentials"
  | "forbidden"
  | "not_found"
  | "email_taken"
  | "username_taken"
  | "conflict"
  | "rate_limited";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export const unauthorized = () => new ApiError(401, "unauthorized", "Je bent niet ingelogd.");
export const notFound = (message = "Niet gevonden.") => new ApiError(404, "not_found", message);
export const forbidden = (message = "Dit mag je niet doen.") => new ApiError(403, "forbidden", message);

/** Postgres unique-violation, optionally for one specific constraint. */
export function isUniqueViolation(error: unknown, constraint?: string): boolean {
  // drizzle wraps driver errors; the pg error is on `cause`.
  const candidates = [error, (error as { cause?: unknown } | null)?.cause];
  return candidates.some((candidate) => {
    const pgError = candidate as { code?: string; constraint?: string } | null | undefined;
    return pgError?.code === "23505" && (!constraint || pgError.constraint === constraint);
  });
}
