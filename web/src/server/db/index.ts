import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import * as schema from "./schema";

function createPool() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL is not set. Copy .env.example to .env.local and fill it in.");
  }
  return new Pool({ connectionString, max: Number(process.env.DATABASE_POOL_MAX ?? 10) });
}

// Reuse one pool across hot reloads in development.
const globalForDb = globalThis as unknown as { __metricPool?: Pool };

export function getPool(): Pool {
  if (!globalForDb.__metricPool) globalForDb.__metricPool = createPool();
  return globalForDb.__metricPool;
}

let cached: ReturnType<typeof drizzle<typeof schema>> | undefined;

export function getDb() {
  if (!cached) cached = drizzle(getPool(), { schema });
  return cached;
}

export type Db = ReturnType<typeof getDb>;
export { schema };
