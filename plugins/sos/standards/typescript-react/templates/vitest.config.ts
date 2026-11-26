// vitest.config.ts — Vitest configuration for React / Next.js projects
// Coverage thresholds: 80% minimum (lines, branches, functions, statements)
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./tests/setup.ts"],
    include: ["**/*.{test,spec}.{ts,tsx}"],
    exclude: [
      "node_modules/**",
      ".next/**",
      "build/**",
      "dist/**",
      "e2e/**",
    ],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html", "lcov"],
      thresholds: {
        lines: 80,
        branches: 80,
        functions: 80,
        statements: 80,
      },
      // Without `include`, files no test imports are left out entirely, so an untested module
      // cannot pull coverage below the threshold. List every source file, then exclude.
      include: ["**/*.{ts,tsx}"],
      // A custom exclude replaces Vitest's defaults, so test files are listed here too.
      exclude: [
        "**/*.{test,spec}.{ts,tsx}",
        "e2e/**",
        "node_modules/",
        "tests/",
        "**/__tests__/**",
        "**/__mocks__/**",
        "**/*.d.ts",
        "**/*.config.{js,mjs,cjs,ts,mts,cts}",
        "**/*.config.*",
        "**/next-env.d.ts",
        "**/types/**",
        "**/*.stories.*",
        ".next/**",
        "out/**",
      ],
    },
  },
});
