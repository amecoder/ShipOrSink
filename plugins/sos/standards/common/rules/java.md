---
paths:
  - "**/*.java"
  - "build.gradle*"
  - "pom.xml"
---

# Java Rules

## Modern Java (17+)

- `record` for DTOs and value objects (immutable by default)
- `sealed` classes/interfaces for restricted type hierarchies
- `Optional<T>` for nullable return types (never for parameters or fields)
- `var` for local variables with obvious types only
- Text blocks (`"""`) for multi-line strings (SQL, JSON)
- Pattern matching for `instanceof` (no explicit cast)
- Switch expressions with `->` syntax (exhaustive, no fall-through)

## Style

- Google Java Style: 2-space indent, 100 char line length
- Javadoc on all public APIs (`@param`, `@return`, `@throws`)
- Cyclomatic complexity: <= 15
- Method length: <= 50 lines (MethodLength)
- File length: <= 800 lines (FileLength)
- Parameter count: <= 6 (use Builder or DTO beyond this)

## Collections & Immutability

- `List.of()`, `Map.of()`, `Set.of()` for immutable collections
- `Collections.unmodifiableList()` / `List.copyOf()` when wrapping mutable
- `final` fields by default in all classes
- `record` instead of POJO for data carriers
- Never return mutable internal collections — return defensive copies

## Stream API

- Prefer streams over manual loops for collection transforms
- Keep stream pipelines readable (max 5 operations, then extract method)
- Use `toList()` (Java 16+) instead of `Collectors.toList()`
- Avoid side effects in stream operations (no mutation inside map/filter)

## Error Handling

- Specific exceptions over generic (`IllegalArgumentException` > `RuntimeException`)
- Never catch `Exception` or `Throwable` in business logic
- Use custom domain exceptions extending `RuntimeException`
- Always include context in exception messages
- Close resources with try-with-resources (never manual close in finally)

## Spring Boot Patterns

- Constructor injection only (no `@Autowired` on fields)
- `@Value` for simple config, `@ConfigurationProperties` for structured config
- `@Transactional` on service layer, not on repository or controller
- Slice tests: `@WebMvcTest`, `@DataJpaTest` (fast, focused)
- No business logic in controllers — delegate to services

## Forbidden

- Field injection (`@Autowired` on fields) — use constructor injection
- `null` returns from public methods — use `Optional<T>`
- Raw types (`List` instead of `List<String>`)
- `System.out.println` — use SLF4J Logger
- Star imports (`import java.util.*`)
- Mutable static fields (thread-safety risk)
- `@SuppressWarnings` without a comment explaining why
- Hardcoded secrets or connection strings
