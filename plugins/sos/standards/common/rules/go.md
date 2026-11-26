---
paths:
  - "**/*.go"
  - "go.mod"
  - "go.sum"
---

# Go Rules

- Follow Uber Go Style Guide conventions
- Errors: always check returned errors, wrap with `fmt.Errorf("...: %w", err)`
- Naming: MixedCaps (exported), mixedCaps (unexported), no underscores
- Interfaces: accept interfaces, return structs
- Keep interfaces small (1-3 methods)
- Use `context.Context` as first parameter
- Table-driven tests with `t.Run()` subtests
- `gofumpt` for formatting (stricter than `gofmt`)
- Cyclomatic complexity: <=15
- Function length: <=50 lines
- Line length: 120 chars

## Error Handling

- Never ignore errors: `_ = f()` is forbidden
- Use sentinel errors: `var ErrNotFound = errors.New("not found")`
- Wrap errors with context: `fmt.Errorf("fetch user %d: %w", id, err)`
- Use `errors.Is()` / `errors.As()` for comparison

## Concurrency

- No goroutine leaks: always ensure goroutines terminate
- Use `errgroup` for parallel operations with error handling
- Protect shared state with `sync.Mutex` or channels
- Prefer channels for communication, mutexes for state

## Forbidden

- `panic()` in library code (only in `main` or test setup)
- `init()` functions (use explicit initialization)
- Global mutable state
- Bare `interface{}` (use `any` with Go 1.18+, but prefer concrete types)
- Hardcoded secrets
