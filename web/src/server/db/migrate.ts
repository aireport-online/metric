import path from "node:path";
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { Pool } from "pg";

// Arbitrary constant; all instances that start at once queue on this lock.
const MIGRATION_LOCK_ID = 7_403_118;

export async function runMigrations(connectionString = process.env.DATABASE_URL) {
  if (!connectionString) throw new Error("DATABASE_URL is not set");
  const pool = new Pool({ connectionString, max: 1 });
  const client = await pool.connect();
  try {
    await client.query("select pg_advisory_lock($1)", [MIGRATION_LOCK_ID]);
    await migrate(drizzle(client), { migrationsFolder: path.join(process.cwd(), "drizzle") });
  } finally {
    await client.query("select pg_advisory_unlock($1)", [MIGRATION_LOCK_ID]).catch(() => {});
    client.release();
    await pool.end();
  }
}
