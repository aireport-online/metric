import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: {
    environment: "node",
    globalSetup: "./tests/global-setup.ts",
    // All files share one test database, so run them one after another.
    fileParallelism: false,
    env: {
      DATABASE_URL: process.env.TEST_DATABASE_URL ?? "postgres://metric:metric@localhost:5432/metric_test",
      DISABLE_RATE_LIMIT: "1",
    },
  },
});
