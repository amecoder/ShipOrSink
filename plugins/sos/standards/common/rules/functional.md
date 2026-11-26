---
paths:
  - "**/*.{py,ts,tsx,js,jsx,java,kt,kts,cs,go,rs,rb,swift,dart}"
---

# Functional Programming Rules

Pure logic is easy to test, reason about, and run anywhere. Push side effects to the edges and keep the middle pure.

## Functional Core, Imperative Shell

- The core computes: decisions, transformations, validation, pricing, scheduling. It takes values and returns values, touches no clock, network, file, database, or global.
- The shell performs: reads input, calls the core, writes output. It is thin, and its correctness is checked by integration tests, not unit tests.
- Test shape follows: core → many fast unit tests with plain values; shell → few integration tests.

## Purity And Effects

- Prefer pure functions: same input, same output, no observable side effect. `computeDiscount(cart, rules)` not `applyDiscount()` that mutates `cart` and logs.
- Make effects visible in the signature. A function that may fail returns a `Result`/`Either`/error value; one that may be absent returns `Option`/nullable; one that does I/O is named and placed so that it is obviously an effect (`fetchUser`, `saveOrder`), never hidden inside a getter.
- Inject time, randomness, and identifiers (`now`, `random`, `idGenerator`) instead of calling them inside logic.
- No shared mutable state between functions or modules. Module-level caches, singletons that change, and static mutable fields need a documented reason and a lock or an owner.

## Data

- Data is immutable by default: build new values instead of mutating (`{ ...user, name }`, `[...items, item]`, `dataclass(frozen=True)` + `tuple`, Kotlin `val` + `copy()`, Java `record`, Rust ownership).
- Model choices as closed sums, not booleans and nullables: `sealed`/`enum`/discriminated unions for `Paid | Refunded | Failed(reason)`; then exhaustiveness checks catch the missing branch.
- Parse, don't validate: turn raw input into a typed value once at the boundary (`Email.parse(str)` → `Email`), and let the type guarantee the rest of the program never sees an invalid string.
- Expected failures are values, not exceptions: "not found", "invalid input", "insufficient funds" return `Result`. Exceptions are for bugs and infrastructure faults.

## Composition

- Build from small functions: `map`/`filter`/`reduce` and composition over hand-rolled loops when it reads clearly; a well-named loop over a clever one-liner.
- Keep functions total where practical: every input in the type has a defined output. Partial functions (`head`, indexing, division) get a checked wrapper.
- Prefer declarative pipelines for data transformation and reserve imperative code for the shell and for hot paths with a measured reason.

## When OOP, When FP

- Entity with invariants and a lifecycle (an `Order` that moves through states) → object that guards its state (see `oop.md`).
- Transformation, calculation, validation, policy evaluation → pure functions over immutable values.
- Both in one codebase is normal: objects hold the invariants, and their methods are implemented as pure functions over their own data.

## Language Notes

- Python: `frozen` dataclasses, `tuple`/`frozenset`, `functools`, return `Result`-like unions via `typing.Union` or a small result type; avoid mutating arguments.
- TypeScript: `readonly`, `as const`, discriminated unions, `never` exhaustiveness, avoid `let` for values that do not change.
- Kotlin: `val`, `data class`, `sealed interface`, `Result`/Arrow `Either`, `when` exhaustiveness.
- Java: `record`, `sealed`, `Stream`, `Optional` at boundaries only, `switch` pattern matching.
- Go: value receivers for pure methods, explicit `error` returns, no package-level mutable vars.
- Rust: ownership makes immutability the default; `Result`/`Option`, iterators over index loops, `match` exhaustiveness.

## Review Checklist

- Business rules are testable without mocks.
- Effects are visible from signatures and names.
- Inputs are parsed into types at the boundary once.
- No function mutates its arguments or hidden state.
- Variants are closed sums with exhaustive handling.
