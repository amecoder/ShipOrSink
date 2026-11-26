/**
 * Playwright E2E Test Configuration
 *
 * 사용법:
 *   1. 이 파일을 프로젝트 루트에 복사
 *   2. baseURL을 프로젝트에 맞게 수정
 *   3. npm install -D @playwright/test
 *   4. npx playwright install
 *   5. 실행: npx playwright test
 *   6. 리포트: npx playwright show-report
 */
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  // Test directory
  testDir: "./e2e",
  testMatch: "**/*.spec.ts",

  // Parallel execution
  fullyParallel: true,
  workers: process.env.CI ? 1 : undefined, // CI: sequential, Local: parallel

  // Retry on failure
  retries: process.env.CI ? 2 : 0,

  // Reporter
  reporter: process.env.CI
    ? [["html", { open: "never" }], ["github"]]
    : [["html", { open: "on-failure" }]],

  // Global settings
  use: {
    // Base URL (modify for your project)
    baseURL: process.env.BASE_URL || "http://localhost:3000",

    // Collect trace on first retry
    trace: "on-first-retry",

    // Screenshot on failure
    screenshot: "only-on-failure",

    // Video on failure
    video: "retain-on-failure",
  },

  // Browser configurations
  projects: [
    // Desktop browsers
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] },
    },

    // Mobile browsers
    {
      name: "mobile-chrome",
      use: { ...devices["Pixel 5"] },
    },
    {
      name: "mobile-safari",
      use: { ...devices["iPhone 13"] },
    },
  ],

  // Local dev server (optional)
  // webServer: {
  //   command: "npm run dev",
  //   url: "http://localhost:3000",
  //   reuseExistingServer: !process.env.CI,
  //   timeout: 120_000,
  // },
});
