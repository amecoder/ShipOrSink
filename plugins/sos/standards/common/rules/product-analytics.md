---
paths:
  - "**/analytics/**"
  - "**/tracking/**"
  - "**/events/**"
  - "**/experiments/**"
  - "**/*tracking*"
  - "**/*analytics*"
  - "**/*experiment*"
  - "**/*Experiment*"
  - "docs/analytics/**"
---

# Product Analytics & Experimentation Rules

Treat product instrumentation and experiments as production code. They drive decisions, so they must be correct, documented, and reviewed.

## Tracking Plan

- Maintain a single tracking plan that defines every event, its properties, types, allowed values, source of truth, owner, and PII flag.
- Event names follow a consistent convention (e.g., `object_action`: `signup_completed`, `checkout_started`).
- Add or change events through a PR that updates the tracking plan, schema, and code together.
- Server-side events are preferred for revenue, conversion, and security signals; client-side events are preferred for UX interactions, but must be cross-checked against server data when used for billing or growth decisions.

## Schema And Quality

- Each event has a versioned JSON schema enforced at ingestion; bad payloads are rejected or quarantined, not silently dropped.
- IDs (user, session, tenant, request) are consistent across services and pipelines.
- PII fields are marked, hashed, or excluded according to the data classification.
- Backfills and reprocessing are explicit and logged.

## Dashboards And Metrics

- Every product KPI has an owner, a definition link in the tracking plan, and a freshness SLA.
- Metric definitions live in code (dbt models, semantic layer, metrics service), not only in BI tool config.
- Dashboards used for goals (NSM, OKRs) are reviewed quarterly for definition drift.

## Experimentation

- Every experiment is declared via the experiment template: hypothesis, primary metric, guardrail metrics, MDE, target sample size, traffic allocation, expected duration, exclusion rules.
- Use a feature flag / experiment platform with deterministic bucketing keyed on stable IDs; do not roll your own randomization for live experiments.
- Define guardrails (latency, error rate, revenue, retention, abuse) and stop rules.
- Pre-register the analysis plan; running until "it looks significant" is not acceptable.
- After the experiment, publish a writeup: result, decision, learnings, follow-up actions; archive the analysis notebook or query.

## Privacy And Consent

- Respect consent state (cookie banner, region rules, age) before sending any analytics event.
- Honor "do not track" / opt-out at the SDK and ingestion layer.
- Cross-border data flows align with the privacy-data-governance rule.

## Operational Hygiene

- Monitor event volume, schema rejections, and pipeline lag; alert on anomalies.
- Treat tracking outages as incidents when they block revenue or compliance reporting.
- Do not block product behavior on analytics calls; analytics is fire-and-forget unless explicitly required.

## Review Checklist

- Tracking plan, schema, and code are updated in the same PR.
- Owner, PII flag, and source of truth are defined for each new event.
- Experiments include hypothesis, primary metric, MDE, guardrails, and analysis plan before launch.
- Consent and data classification are respected.
- Dashboards used for decisions reference versioned metric definitions.
