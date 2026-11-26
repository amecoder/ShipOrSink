---
paths:
  - "**/*.py"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.java"
  - "**/*.kt"
---

# OpenTelemetry / Observability Rules

These rules apply when writing instrumentation, logging, or metrics code.

## Span Naming Convention

- HTTP server: `{METHOD} {route}` (e.g., `GET /api/users/:id`)
- HTTP client: `{METHOD}` (e.g., `POST`)
- Database: `{operation} {table}` (e.g., `SELECT users`)
- Messaging: `{destination} {operation}` (e.g., `orders.queue process`)
- Internal: `{Component}.{operation}` (e.g., `PaymentService.processRefund`)

## Attribute Naming

- Use OTel semantic conventions namespace format: `{namespace}.{name}`
- Standard: `http.request.method`, `db.system.name`, `rpc.method` (fully-qualified, e.g. `myservice.EchoService/Echo` — `rpc.service` is deprecated)
- Custom: prefix with `app.` (e.g., `app.user.id`, `app.order.total`)
- No PII in attributes (user email, phone, SSN)

## Structured Logging

- JSON format mandatory in production
- Required fields: `timestamp`, `level`, `message`, `service`, `trace_id`, `span_id`
- Log levels: ERROR (immediate action), WARN (potential issue), INFO (business events), DEBUG (dev only)
- No PII in logs (mask sensitive data)
- No DEBUG logs enabled in production

## Metrics Naming (Prometheus Convention)

- `snake_case` with unit suffix: `http_request_duration_seconds`
- Counter: `_total` suffix (e.g., `http_requests_total`)
- Histogram: `_seconds` / `_bytes` (e.g., `db_query_duration_seconds`)
- Gauge: no suffix (e.g., `active_connections`)

## Mandatory Instrumentation Points

- HTTP handler entry/exit (auto-instrumented by OTel SDK)
- Database queries (auto-instrumented)
- External API calls
- Message queue publish/consume
- Business-critical operations (payment, auth, order)

## Forbidden

- Logging sensitive data (passwords, tokens, PII)
- High-cardinality metric labels (user ID, request ID as label)
- Synchronous span export in hot paths
- Missing `trace_id` correlation in logs
