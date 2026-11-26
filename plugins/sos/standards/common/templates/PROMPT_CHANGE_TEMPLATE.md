# Prompt Change Template

Use this template for any change to a production prompt, system instruction, tool schema, or agent graph. Attach to the PR.

## Metadata

- Prompt ID / file path:
- Version (before → after):
- Owner:
- Linked AI Task Spec / PRD / Feature Spec:
- Models the prompt is used with:

## Reason For Change

- Problem observed:
- Hypothesis:
- Expected user-visible impact:

## Diff Summary

- High-level diff (what was added / removed / clarified):
- Risk areas (tone, factuality, safety, output format):

## Eval Results

| Eval suite | Before | After | Delta | Pass / Fail |
|------------|--------|-------|-------|-------------|
| Golden cases | | | | |
| Regression cases | | | | |
| Adversarial / jailbreak | | | | |
| Hallucination / factuality | | | | |
| Latency p50 / p95 | | | | |
| Cost per request | | | | |

- Eval run ID / artifact link:
- Cases that regressed (and why it is acceptable):

## Safety / Compliance

- [ ] No PII or secrets in prompt or eval dataset.
- [ ] Output guardrails (toxicity, schema, policy) tested.
- [ ] Prompt injection defenses considered for untrusted input.
- [ ] Vendor / data classification rules respected.

## Rollout Plan

- [ ] Canary or A/B with traffic %, duration, success metric:
- [ ] KPIs to watch (CSAT, deflection, conversion, error rate):
- [ ] Rollback path (previous prompt version + previous model snapshot):

## Sign-Off

- Engineering:
- Product / domain expert:
- Safety / policy reviewer (if applicable):
