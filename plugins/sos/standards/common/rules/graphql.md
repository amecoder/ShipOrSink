---
paths:
  - "**/*.graphql"
  - "**/*.gql"
  - "**/schema.*"
  - "**/resolvers/**"
  - "**/typeDefs/**"
---

# GraphQL Rules

## Schema Design

- PascalCase for types and enums: `User`, `OrderStatus`
- camelCase for fields and arguments: `firstName`, `createdAt`
- SCREAMING_SNAKE_CASE for enum values: `IN_PROGRESS`, `OUT_OF_STOCK`
- Suffix input types with `Input`: `CreateUserInput`, `UpdateOrderInput`
- Suffix connection types with `Connection`: `UserConnection`, `OrderConnection`
- Suffix edge types with `Edge`: `UserEdge`
- Prefix boolean fields with `is`, `has`, `can`: `isActive`, `hasPermission`
- All fields require descriptions (enforce with linter)

## Pagination (Relay Cursor Specification)

- Use Relay-style cursor pagination for all list queries
- `Connection` type with `edges`, `pageInfo`, `totalCount`
- `Edge` type with `node` and `cursor`
- `PageInfo` with `hasNextPage`, `hasPreviousPage`, `startCursor`, `endCursor`
- Arguments: `first`, `after`, `last`, `before`

```graphql
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}
```

## Error Handling

- Use union types for expected errors (not exceptions)
- Suffix error types with `Error`: `NotFoundError`, `ValidationError`
- Payload types return `Result` union: `type CreateUserPayload = User | ValidationError`
- Reserve GraphQL errors for unexpected/system failures only
- Include `userMessage` (display) and `code` (machine-readable) in error types

```graphql
type ValidationError {
  code: String!
  message: String!
  field: String
}

union CreateUserResult = User | ValidationError | NotFoundError

type Mutation {
  createUser(input: CreateUserInput!): CreateUserResult!
}
```

## Query Design

- Queries are read-only, idempotent, and side-effect-free
- Mutations for all write operations
- Subscriptions only for real-time features (not polling replacement)
- Query depth limit: <= 7 levels
- Query complexity limit enforced server-side
- No deeply nested mutations (1 level of nesting max)

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Query field | `camelCase`, noun | `user`, `orders` |
| Mutation field | `camelCase`, verb+noun | `createUser`, `cancelOrder` |
| Subscription | `camelCase`, `on`+event | `onOrderUpdated` |
| Input type | `PascalCase` + `Input` | `CreateUserInput` |
| Payload type | `PascalCase` + `Payload`/`Result` | `CreateUserResult` |
| Enum type | `PascalCase` | `OrderStatus` |
| Enum value | `SCREAMING_SNAKE` | `IN_PROGRESS` |

## Performance

- DataLoader for N+1 prevention (batch + cache per request)
- Persisted queries in production (hash-based, no arbitrary query strings)
- Field-level cost analysis for complexity limiting
- `@defer` and `@stream` directives for large responses
- Response caching with `@cacheControl` directives

## Security

- Disable introspection in production
- Query depth and complexity limits enforced at gateway
- Rate limiting per client/operation
- Input validation in resolvers (max string length, regex patterns)
- Authentication/authorization at resolver level (not schema directives only)
- No sensitive data in error messages

## Versioning

- Prefer schema evolution over versioning (add fields, deprecate old)
- `@deprecated(reason: "Use newField instead")` with migration deadline
- Breaking changes require minimum 90-day deprecation period
- Monitor deprecated field usage before removal

## Forbidden

- Deeply nested input types (flatten to single level)
- Nullable list items (`[User]` — use `[User!]!` or `[User!]`)
- Generic error strings without structured error types
- Unbounded list queries without pagination
- `ID` type for non-identifier fields
- Introspection enabled in production
- Mutations that return `Boolean` (return the affected entity)
- Hardcoded resolver logic over 50 lines (extract to service layer)
