---
paths:
  - "**/prompts/**"
  - "**/prompt/**"
  - "**/llm*/**"
  - "**/ai/**"
  - "**/agents/**"
  - "**/chains/**"
  - "**/*prompt*"
  - "**/*Prompt*"
  - "**/evals/**"
  - "docs/llmops/**"
---

# LLMOps / PromptOps Governance Rules

Apply these rules to any code path that calls an LLM, embedding model, vision model, speech model, agent, or RAG pipeline.

## Versioning

- Prompts, system instructions, tool/function schemas, and agent graphs are stored in source control with semantic file names and version IDs.
- Prompt changes go through a PR with diff, owner, rationale, and an updated eval result.
- Models, providers, temperatures, top-p, max tokens, safety settings, and tool sets are configured, not hardcoded; config is versioned and environment-pinned.
- Pin model snapshots (e.g., `gpt-x-2026-01-15`) for production. "Latest" aliases are forbidden in prod.

## Evaluation Before Release

- Every prompt or model change runs the project eval harness (see ai-eval-harness rule).
- Required eval coverage: golden cases, regression cases, adversarial / jailbreak cases, hallucination/factuality checks, latency, cost.
- Eval results are attached to the PR (artifact or link). Score regressions block merge unless explicitly accepted with reason and owner.
- Human review is required for changes that affect user-visible safety, tone, or factual claims.

## Runtime Controls

- Every LLM call records: prompt template ID + version, model + version, latency, input/output token counts, cost, request ID, user/tenant ID, route.
- Rate limits, per-tenant quotas, and circuit breakers protect upstream cost and downstream latency.
- Retry policy is bounded; failed calls fall back to a documented degraded path.
- PII is redacted or tokenized before logging prompts and responses; retention follows the data retention policy.
- Tool/function calls are allowlisted; arguments are validated server-side; destructive tools require confirmation or a separate authz scope.

## Safety And Compliance

- Output guardrails (toxicity, policy, schema validation) are enforced for user-facing responses.
- Prompt injection defenses (system/tool isolation, input sanitization, escape characters) are applied for any flow that ingests untrusted text.
- Data sent to providers respects the data classification (no high-sensitivity data to non-approved providers).
- Vendor changes (new provider, region, sub-processor) follow the vendor risk template.

## Cost And Reliability Budgets

- Each AI feature has a cost-per-request and cost-per-day budget; alerts fire before budget breach.
- p50/p95 latency targets are defined and tracked per endpoint and per model.
- Switching to a cheaper model or smaller context is documented as a degraded mode.

## Release / Rollback

- Prompt and model changes deploy progressively (canary or A/B), with eval-based gates and live KPI gates.
- A rollback path (previous prompt version + previous model snapshot) is one click or one config change away.
- Post-incident: replay failing inputs against the prior version to confirm regression scope.

## Review Checklist

- Prompt/model change is a normal PR with diff, eval result, and owner.
- Telemetry covers token, cost, latency, error class, and tenant.
- Safety guardrails and prompt-injection defenses are present for untrusted input.
- Budgets and rollback path are explicit.
- No secret keys, customer data, or unredacted PII in prompt logs or eval datasets.
