/** Runs once when the server starts. With MIGRATE_ON_START=1 (the Docker image) it applies pending migrations. */
export async function register() {
  if (process.env.NEXT_RUNTIME !== "nodejs" || process.env.MIGRATE_ON_START !== "1") return;
  const { runMigrations } = await import("./server/db/migrate");
  await runMigrations();
  console.log("Database migrations are up to date.");
}
