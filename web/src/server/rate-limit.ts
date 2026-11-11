import { ApiError } from "./errors";

type Bucket = { count: number; resetAt: number };

// In-memory, so it protects a single server process. Behind several instances,
// put a shared limiter (reverse proxy or Redis) in front of the auth endpoints.
const buckets = new Map<string, Bucket>();

export function rateLimit(key: string, limit: number, windowMs: number) {
  if (process.env.DISABLE_RATE_LIMIT === "1") return;
  const now = Date.now();
  if (buckets.size > 10_000) {
    for (const [k, bucket] of buckets) if (bucket.resetAt <= now) buckets.delete(k);
  }
  const bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return;
  }
  bucket.count += 1;
  if (bucket.count > limit) {
    throw new ApiError(429, "rate_limited", "Te veel pogingen. Probeer het over een paar minuten opnieuw.");
  }
}
