---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "build.gradle*"
---

# Kotlin Rules

- `data class` for value objects, `sealed class` for restricted hierarchies
- `val` over `var` (immutability by default)
- Extension functions for utility methods
- `require()` / `check()` for preconditions
- Coroutine scope for structured concurrency
- KDoc on all public APIs (`@param`, `@return`, `@throws`)
- Cyclomatic complexity: <=15
- Function length: <=50 lines (LongMethod)
- File/class size: <=600 lines (LargeClass)
- Line length: 100 chars

## Forbidden

- Field injection (`@Autowired` on fields) — use constructor injection
- `!!` (non-null assertion) — use safe calls or `requireNotNull()`
- `var` for collections — use `val` + read-only `List`
- Circular dependencies between packages
- Hardcoded secrets
