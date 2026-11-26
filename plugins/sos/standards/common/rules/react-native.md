---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/android/**"
  - "**/ios/**"
  - "app.json"
  - "metro.config.*"
  - "babel.config.*"
---

# React Native Rules

- Functional components only (no class components)
- `Platform.select()` or `Platform.OS` for platform-specific logic
- `SafeAreaView` wrapping all top-level screens
- `FlatList` over `ScrollView` for lists (virtualization)
- `StyleSheet.create()` for all styles (no inline style objects)
- `useCallback`/`useMemo` for expensive computations and list item renders
- Absolute imports via `tsconfig.json` paths (`@/components/Button`)
- Function length: <= 50 lines
- File size: <= 800 lines
- Complexity: <= 15

## Navigation

- React Navigation with typed routes (`RootStackParamList`)
- Deep linking configuration in `app.json` or `linking` config
- Screen names as constants (no hardcoded strings)

## Native Module Patterns

- New Architecture (Fabric + TurboModules) for React Native 0.76+
- Codegen specs in `src/specs/` directory
- Native module interface defined in TypeScript spec file
- Bridge calls wrapped in async utility functions (not called directly in components)

## Performance

- `React.memo()` on list item components
- Image optimization: `react-native-fast-image` or built-in `Image` with caching
- Avoid anonymous functions in `renderItem` props
- Hermes engine enabled (default in RN 0.70+)
- Bundle splitting for large apps (re.pack or Metro lazy bundling)

## Platform-Specific Code

```
# Preferred patterns for platform branching
Button.ios.tsx     # File-based platform split
Button.android.tsx
Button.tsx         # Shared fallback

# Or inline:
Platform.select({ ios: value, android: value, default: value })
```

## State Management

- React Query / TanStack Query for server state
- Zustand or Jotai for client state (lightweight over Redux)
- MMKV for persistent storage (not AsyncStorage for performance-critical data)

## Testing

- `@testing-library/react-native` for component tests
- Detox or Maestro for E2E tests
- Jest mocks for native modules (`jest.mock('react-native-camera')`)

## Forbidden

- `any` type (use `unknown` + type guard)
- Inline styles (`style={{ flex: 1 }}`) — use `StyleSheet.create()`
- `console.log` in production code
- Direct native module bridge calls in components
- `AsyncStorage` for large or frequent data (use MMKV)
- `ScrollView` for long lists (use `FlatList` or `FlashList`)
- Hardcoded pixel values without responsive scaling
- `@ts-ignore` without explanation comment
