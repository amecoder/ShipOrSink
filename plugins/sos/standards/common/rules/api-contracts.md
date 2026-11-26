---
paths:
  - "**/openapi*.{yml,yaml,json}"
  - "**/asyncapi*.{yml,yaml,json}"
  - "**/*.proto"
  - "**/api/**"
  - "**/routes/**"
---

# API Contract Rules

Public APIs, internal service APIs, and event contracts must be treated as versioned products.

## Contract First

- Define or update OpenAPI, AsyncAPI, GraphQL schema, or Protobuf before implementing a public contract change.
- Include request/response schemas, error responses, auth requirements, rate limits, idempotency, and examples.
- API names should use product vocabulary, not database table names or implementation details.
- Avoid breaking changes. When unavoidable, document migration path and deprecation date.
- Breaking changes to OpenAPI and Protobuf specs are blocked in CI by `oasdiff breaking --fail-on ERR` and `buf breaking` against the base branch (`ci-api-contract.yml`). Ship intentional breaks as a new version path or package, never by disabling the check.

## HTTP APIs

- Use resource-oriented naming and stable identifiers.
- Use RFC 9457-style problem details or a project-standard error envelope.
- Pagination, filtering, sorting, and idempotency must be explicit.
- Validate all input at the edge and normalize once.
- Do not expose stack traces, provider messages, internal IDs, or raw SQL errors.

## Event APIs

- Use AsyncAPI or an equivalent schema registry for production events.
- Include event id, source, type, schema version, subject or aggregate id, occurred time, and trace context.
- Consumers must tolerate unknown fields and duplicate delivery.
- Producers must publish compatibility notes for schema changes.

## Review Checklist

- Contract file changed with implementation.
- Compatibility impact is documented.
- Generated clients or contract tests are updated when used.
- Auth, privacy, and rate-limit behavior are visible in the contract.
- Examples are realistic and free of secrets.
