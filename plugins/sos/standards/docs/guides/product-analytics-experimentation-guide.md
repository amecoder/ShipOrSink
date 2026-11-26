# Product Analytics & Experimentation Guide

## Goal

Make data-driven decisions on real, agreed-upon metrics. Run experiments that measure the right thing safely. Treat analytics and experimentation as production engineering, not a side project.

## Foundations

- One tracking plan as the source of truth for events, properties, owners, PII flags.
- Server-side events for revenue, conversion, security signals. Client-side events for UX interactions. Reconcile both for any metric that affects billing or growth decisions.
- Stable, consistent identifiers (user, session, tenant, request, anonymous) across services and pipelines.
- Schemas enforced at ingestion. Bad payloads quarantined, not silently dropped.

## Naming And Conventions

- Event names: `<object>_<action>` past tense, e.g., `signup_completed`, `checkout_started`.
- Properties: `snake_case`, ISO 8601 UTC for times, ISO 4217 + minor units for money.
- Use the Tracking Plan template to keep the catalog current.

## Quality Gates

- Schema rejection rate has alerts.
- Volume drops or spikes have alerts.
- Server-side / client-side reconciliation report for revenue and conversion.
- Periodic data audit: pick a recent metric, recompute from raw, compare to dashboard.

## Metric Definitions

- Define metrics in code (dbt, semantic layer, metrics service), not only in BI tool config.
- Each KPI has owner, definition link, freshness SLA.
- Review NSM / OKR dashboards quarterly for definition drift.

## Experimentation

- Use a feature flag / experimentation platform with deterministic bucketing on stable IDs. Do not roll your own randomization for live experiments.
- Pre-register the experiment via the Experiment template: hypothesis, primary metric, MDE, target sample size, traffic allocation, guardrails, analysis plan, exclusion rules.
- Run for the planned duration. "Looks significant" is not a valid stop condition unless the analysis was sequential by design.
- Always include guardrail metrics: latency, error rate, revenue, retention, abuse / fraud.
- Publish a writeup after every experiment: result, decision, learnings, follow-ups. Archive the analysis notebook or query.

## Common Pitfalls

- Sample ratio mismatch (assignment skew). Validate split before reading results.
- Peeking at p-values daily and stopping early. Use sequential / Bayesian methods if you need that.
- Analyzing user-level metrics on session-level randomization.
- Overlapping experiments that interact. Use mutual exclusion or factorial design.
- Letting the platform do the math but never validating: SRM, novelty effect, primacy effect, holiday weeks.

## Privacy And Consent

- Honor consent state at the SDK and ingestion layer.
- Cross-border flows match data residency commitments.
- PII fields are minimized, hashed, or tokenized per the data classification.
- DSR (delete / export) requests apply to analytics stores too.

## Operational Hygiene

- Treat analytics outages as incidents when they block revenue or compliance reporting.
- Do not block product behavior on analytics calls; analytics is fire-and-forget unless explicitly required.
- Backfills are explicit, logged, and tested in staging.

## Adoption Steps

1. Write down the tracking plan for the top three flows.
2. Add schema enforcement and a quarantine path.
3. Wire schema rejection and volume alerts.
4. Move metric definitions into code.
5. Adopt the experiment template; require it for all live experiments.
6. Run a first experiment end-to-end and use the writeup as the example.

## References

- "Trustworthy Online Controlled Experiments" — Kohavi, Tang, Xu.
- Segment / Avo / Iteratively documentation on tracking plans.
- Microsoft ExP, https://aka.ms/exp .
- Google "Overlapping Experiment Infrastructure" paper.
