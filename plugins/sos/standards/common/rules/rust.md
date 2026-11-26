---
paths:
  - "**/*.rs"
  - "Cargo.toml"
  - "Cargo.lock"
---

# Rust Rules

- Follow the Rust API Guidelines: https://rust-lang.github.io/api-guidelines/
- Use `Result<T, E>` with the `?` operator for error propagation
- Prefer `thiserror` for library errors, `anyhow` for application errors
- `clippy::correctness` and `clippy::suspicious` are deny-level — never suppress
- `rustfmt` with edition 2024 — never commit unformatted code
- Complexity: <=15 (clippy cognitive complexity — clippy has no cyclomatic lint)
- Function length: <=100 lines
- Line length: 100 chars
- File length: <=800 lines

## Error Handling

- Never use `.unwrap()` or `.expect()` in library/production code
- Define domain error types with `thiserror::Error`
- Propagate errors with `?` operator, add context with `.map_err()` or `anyhow::Context`
- Use `Result` return types, not `panic!()`
- Log errors at the boundary, propagate everywhere else

## Ownership & Borrowing

- Prefer borrowing (`&T`, `&mut T`) over cloning
- Use `Cow<'_, str>` when ownership is conditionally needed
- Avoid unnecessary `clone()` — clippy::redundant_clone catches this
- Lifetime annotations: explicit only when compiler cannot infer
- Prefer `impl Trait` over `dyn Trait` when possible (static dispatch)

## Safety

- `unsafe` is denied by default (`#![deny(unsafe_code)]`)
- If `unsafe` is absolutely required: wrap in a safe abstraction, document invariants with `// SAFETY:` comment
- Never expose `unsafe` in public API without a `# Safety` doc section
- Use `cargo audit` and `cargo deny` before every release
- No hardcoded secrets — use environment variables or config files

## Concurrency

- Prefer `tokio` or `async-std` for async — avoid raw threads unless necessary
- Use `Arc<Mutex<T>>` sparingly; prefer message passing with channels
- Mark shared state types as `Send + Sync` explicitly
- Use `tokio::select!` for concurrent async operations
- Avoid blocking calls inside async contexts (`tokio::task::spawn_blocking`)

## Performance

- Pre-allocate collections: `Vec::with_capacity(n)`, `String::with_capacity(n)`
- Prefer iterators over indexed loops
- Avoid unnecessary allocations: `&str` over `String` where possible
- Use `#[inline]` judiciously — only for small, hot functions
- Profile before optimizing (cargo-flamegraph, criterion)

## Forbidden

- `panic!()`, `unwrap()`, `expect()` in production code
- `unsafe` without `// SAFETY:` justification and safe wrapper
- `println!()` / `eprintln!()` — use `tracing` or `log` crate
- `std::thread::sleep` in async code
- Wildcard dependencies (`version = "*"`)
- Global mutable state (`static mut`)
