---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/*.cts"
  - "tsconfig*.json"
---

# TypeScript Rules

- `strict: true` in tsconfig.json (no exceptions)
- `unknown` over `any` — use type guards for narrowing
- Discriminated unions for state management
- `as const` assertions for literal types
- Branded types for domain primitives (`UserId`, `Email`)
- Exhaustive switch with `assertNever(x: never)` pattern
- `readonly` on interface properties by default
- TSDoc (`/** */`) on all exported functions/types
- Function length: <=50 lines
- File size: <=800 lines
- Complexity: <=15
- Line length: 80 chars

## React / Next.js Specific

- Functional components only (no class components)
- Server Components by default, `"use client"` only when needed
- No inline styles — use Tailwind CSS or CSS modules
- `useCallback`/`useMemo` only when profiled (React 19 compiler handles most cases)
- No `useEffect` for data fetching — use Server Components or React Query

## Forbidden

- `any` type (use `unknown` + type guard)
- `@ts-ignore` / `@ts-expect-error` without explanation comment
- `console.log` in production code
- `var` keyword (use `const` / `let`)
- Non-null assertion `!` without justification
- Hardcoded secrets or API keys
- `innerHTML` or `dangerouslySetInnerHTML` without sanitization
