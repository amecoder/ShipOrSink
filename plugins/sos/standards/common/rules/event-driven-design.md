---
paths:
  - "**/events/**"
  - "**/consumers/**"
  - "**/producers/**"
  - "**/subscribers/**"
  - "**/messaging/**"
  - "**/kafka/**"
  - "**/rabbitmq/**"
  - "**/queue/**"
  - "**/queues/**"
  - "**/asyncapi*.{yml,yaml,json}"
---

# Event-Driven Design Rules

Use event-driven design only when loose coupling, asynchronous processing, auditability, or workflow fan-out is worth the operational cost.

## Event Design

- Name events as facts that already happened: `MeetingTranscribed`, `InvoicePaid`, `UserInvited`.
- Events must include stable identifiers, producer, schema version, occurrence time, and trace/correlation identifiers.
- Treat event payloads as public contracts. Version them and keep backward compatibility.
- Do not publish vague events such as `Updated`, `Changed`, or `Synced` without a domain-specific reason.
- Do not put secrets, raw credentials, or unnecessary PII in events.

## Delivery Semantics

- Assume at-least-once delivery unless the platform proves otherwise.
- Consumers must be idempotent using event id, aggregate version, or a deduplication key.
- Retries need bounded backoff, dead-letter handling, and replay strategy.
- Long-running workflows should use Saga or process manager patterns with explicit compensations.
- Use the transactional outbox pattern when database state and events must commit together.

## Schema And Contracts

- Maintain event schemas in AsyncAPI, JSON Schema, Protobuf, or Avro.
- Additive changes are preferred. Removing or changing semantics requires a migration plan.
- Consumers must tolerate unknown fields.
- Breaking event changes require producer/consumer compatibility review and rollout sequencing.

## Operations

- Define owner, retention, partitioning key, replay policy, DLQ policy, and alert thresholds for every production topic/stream.
- Track consumer lag, error rate, retry rate, DLQ count, and processing latency.
- Do not use events as hidden RPC. If a synchronous answer is required, use an API call.

## Review Checklist

- The event represents a real domain fact.
- The producer and consumer ownership model is clear.
- Idempotency and replay behavior are tested.
- Schema compatibility has been checked before deployment.
- PII and retention impact are documented.
