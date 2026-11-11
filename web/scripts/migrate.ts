import { config } from "dotenv";
import { runMigrations } from "../src/server/db/migrate";

config({ path: ".env.local", quiet: true });

runMigrations()
  .then(() => console.log("Migrations applied."))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
