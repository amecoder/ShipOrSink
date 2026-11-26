---
paths:
  - "**/*.swift"
  - "Package.swift"
---

# Swift Rules

- `let` over `var` (immutability by default)
- `struct` over `class` unless reference semantics needed
- `guard` for early returns (avoid deep nesting)
- Access control: `private` by default, expose only what's needed
- Protocol-oriented design: small, composable protocols
- `async/await` for concurrency (avoid raw GCD)
- Documentation comments (`///`) on all public APIs
- Cyclomatic complexity: <=15
- Function length: <=50 lines
- File size: <=800 lines
- Line length: 120 chars

## SwiftUI Patterns

- Small, composable views (one view = one responsibility)
- Extract subviews into separate `struct` (not computed properties)
- `@State` for local state, `@Binding` for parent-owned state
- `@Observable` (iOS 17+) over `ObservableObject` where possible
- `@Environment` for dependency injection
- Preview providers for all views

## Error Handling

- `Result<T, Error>` for failable operations
- Custom error types conforming to `LocalizedError`
- Never catch all errors silently (`catch { }` without handling)
- `throws` on functions that can fail (propagate errors)

## Naming

- Types: UpperCamelCase (`UserProfile`, `NetworkService`)
- Functions/properties: lowerCamelCase (`fetchUser`, `isValid`)
- Boolean: `is`/`has`/`should` prefix (`isLoading`, `hasPermission`)
- Protocols: nouns for capabilities (`Identifiable`), `-able`/`-ible` for behavior

## Forbidden

- Force unwrapping (`!`) — use `guard let`, `if let`, or `??`
- Force casting (`as!`) — use `as?` with nil handling
- Force try (`try!`) — use `do/catch` or `try?`
- Implicitly unwrapped optionals (except `@IBOutlet`)
- `var` for collections when mutation not needed
- Hardcoded secrets or API keys
- `print()` in production (use `os.Logger` or logging framework)
- Massive view controllers / views (>600 lines)
