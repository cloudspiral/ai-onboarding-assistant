import { defineConfig, devices } from "@playwright/test";

const liveBaseURL = process.env.LIVE_BASE_URL;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  retries: 0,
  reporter: "line",
  use: { baseURL: liveBaseURL ?? "http://127.0.0.1:3100", trace: "retain-on-failure" },
  webServer: liveBaseURL ? undefined : { command: "npm run dev -- -p 3100 -H 127.0.0.1", url: "http://127.0.0.1:3100", reuseExistingServer: false, timeout: 120_000 },
  projects: [ { name: "chromium", use: { ...devices["Desktop Chrome"] } } ],
});
