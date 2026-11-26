---
paths:
  - "**/*.dart"
  - "pubspec.yaml"
---

# Dart / Flutter Rules

- `final` for all local variables (`prefer_final_locals`)
- `const` constructors wherever possible (`prefer_const_constructors`)
- Immutable state: `@freezed` or `@immutable` annotations
- Single quotes for strings (`prefer_single_quotes`)
- Trailing commas on all multi-line arguments (`require_trailing_commas`)
- Type annotations on all public APIs (`type_annotate_public_apis`)
- Never use `print()` — use `debugPrint()` or logger (`avoid_print`)
- Cyclomatic complexity: <=15
- Function length: <=50 lines
- File size: <=800 lines
- Line length: 80 chars

## Widget Design

- Small, focused widgets (one widget = one responsibility)
- Extract widgets into separate files (not methods returning widgets)
- `const` widgets for static subtrees
- `Key` parameter on all public widgets
- Build methods must be pure (no side effects)

## State Management (Riverpod / Bloc)

- Riverpod: `@riverpod` annotation for providers, `ref.watch` over `ref.read` in build
- Bloc: single event per user action, states as `sealed class`
- Never mutate state directly — always emit/return new state
- Dispose subscriptions in `dispose()` or use `ref.onDispose`

## Testing

- Widget tests: `testWidgets()` with `pumpWidget()` + `pumpAndSettle()`
- Golden tests: pixel-perfect regression with `matchesGoldenFile()`
- Unit tests: `group()` + `test()` for business logic
- Coverage: >=80% (`flutter test --coverage`)

## Forbidden

- `print()` in production code (use `debugPrint` or logging)
- Force unwrap (`!` on nullable) without justification
- `dynamic` type (use `Object` or generics)
- `setState()` in complex widgets (use state management)
- Mutable global state
- Hardcoded secrets or API keys
- `import 'package:flutter/widgets.dart'` (use `material.dart` or `cupertino.dart`)
