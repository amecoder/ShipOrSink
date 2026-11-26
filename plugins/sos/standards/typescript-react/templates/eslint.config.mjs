// eslint.config.mjs — ESLint 9+ Flat Config for TypeScript / React / Next.js
// Quality standard: BigTech-grade linting with accessibility and import ordering
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { defineConfig, globalIgnores } from "eslint/config";
import js from "@eslint/js";
import prettierConfig from "eslint-config-prettier";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";
import importX from "eslint-plugin-import-x";
import jsxA11y from "eslint-plugin-jsx-a11y";
import reactHooks from "eslint-plugin-react-hooks";
import tseslint from "typescript-eslint";

const tsconfigRootDir = dirname(fileURLToPath(import.meta.url));

export default defineConfig([
  // ── Global ignores ──────────────────────────────────────────────────────
  globalIgnores([
    ".next/**",
    "out/**",
    "build/**",
    "dist/**",
    "coverage/**",
    "node_modules/**",
    "next-env.d.ts",
    "*.config.{js,mjs,cjs,ts,mts,cts}",
    "vitest.config.*",
  ]),

  // ── Base: ESLint recommended ────────────────────────────────────────────
  js.configs.recommended,

  // ── Next.js official flat config: Core Web Vitals + TypeScript ──────────
  ...nextVitals,
  ...nextTs,

  // ── TypeScript: strict type-checked rules ───────────────────────────────
  ...tseslint.configs.strictTypeChecked.map((config) => ({
    ...config,
    files: ["**/*.{ts,tsx,mts,cts}"],
    languageOptions: {
      ...config.languageOptions,
      parserOptions: {
        ...config.languageOptions?.parserOptions,
        projectService: true,
        tsconfigRootDir,
      },
    },
  })),

  // ── React Hooks ─────────────────────────────────────────────────────────
  reactHooks.configs.flat.recommended,

  // ── Accessibility (WCAG 2.1 AA) ────────────────────────────────────────
  // eslint-config-next already registers the jsx-a11y plugin (6 rules). Add the full recommended
  // rule set without registering the plugin again — that fails with "Cannot redefine plugin".
  // Same files as eslint-config-next's plugin block: without them the rules also hit *.cjs files, where the
  // plugin is not registered, and `eslint .` aborts with exit 2 ("could not find plugin jsx-a11y").
  {
    files: ["**/*.{js,jsx,mjs,ts,tsx,mts,cts}"],
    rules: jsxA11y.flatConfigs.recommended.rules,
  },

  // ── CommonJS config files (.dependency-cruiser.cjs …) ───────────────────
  // commonjs gives them module / require / exports, so no-undef does not flag `module.exports`
  { files: ["**/*.cjs"], languageOptions: { sourceType: "commonjs" } },

  // ── Import ordering and validation ─────────────────────────────────────
  {
    plugins: { "import-x": importX },
    rules: {
      "import-x/order": [
        "warn",
        {
          groups: [
            "builtin",
            "external",
            "internal",
            "parent",
            "sibling",
            "index",
            "type",
          ],
          "newlines-between": "always",
          alphabetize: { order: "asc", caseInsensitive: true },
        },
      ],
      "import-x/no-duplicates": "error",
      "import-x/no-unresolved": "off", // TypeScript handles this
    },
  },

  // ── Project custom rules ───────────────────────────────────────────────
  {
    rules: {
      // Console usage
      "no-console": ["warn", { allow: ["warn", "error"] }],

      // Complexity control — "error", not "warn": `eslint .` exits 0 on warnings, so CI would not block.
      // Numbers come from common/quality-thresholds.yaml; tests/enforcement.bats proves they block.
      complexity: ["error", { max: 15 }],
      "max-lines-per-function": [
        "error",
        { max: 50, skipBlankLines: true, skipComments: true },
      ],
      "max-lines": [
        "error",
        { max: 800, skipBlankLines: true, skipComments: true },
      ],
    },
  },

  // TypeScript-only rules — type-aware ones crash `eslint .` on a plain .js file ("requires type information")
  {
    files: ["**/*.{ts,tsx,mts,cts}"],
    rules: {
      // Unused variables (error, not warn)
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],

      // Type safety
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-misused-promises": "error",
      "@typescript-eslint/consistent-type-imports": [
        "warn",
        { prefer: "type-imports", fixStyle: "inline-type-imports" },
      ],
    },
  },

  // Test files: describe()/it() callbacks are long by nature — same exception as Go (*_test.go has no funlen)
  {
    files: ["**/*.{test,spec}.{ts,tsx}", "tests/**", "e2e/**"],
    rules: { "max-lines-per-function": "off" },
  },

  // ── Disable rules that conflict with Prettier ──────────────────────────
  prettierConfig,
]);
