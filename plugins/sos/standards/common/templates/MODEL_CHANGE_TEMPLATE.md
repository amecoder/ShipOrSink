# Model Change Template

Use this template when changing the model, provider, snapshot, or runtime configuration (temperature, top-p, max tokens, tool set, safety settings) for a production AI feature.

## Metadata

- Feature / route:
- Owner:
- Current model + snapshot + provider:
- Proposed model + snapshot + provider:
- Linked Prompt Change PR (if any):

## Reason For Change

- Driver: cost / latency / quality / safety / compliance / EOL / vendor change
- Problem observed (with metrics, dates, examples):
- Expected outcome:

## Configuration Diff

| Setting | Before | After |
|---------|--------|-------|
| Provider |  |  |
| Model snapshot |  |  |
| Temperature |  |  |
| Top-p |  |  |
| Max tokens |  |  |
| Tool / function set |  |  |
| Safety / moderation settings |  |  |
| Region / data residency |  |  |
| Sub-processor changes |  |  |

## Eval Results

| Eval suite | Before | After | Delta | Pass / Fail |
|------------|--------|-------|-------|-------------|
| Golden cases | | | | |
| Regression cases | | | | |
| Adversarial / jailbreak | | | | |
| Hallucination / factuality | | | | |
| Latency p50 / p95 | | | | |
| Cost per request | | | | |
| Token usage p50 / p95 | | | | |

- Eval run ID / artifact link:
- Notable regressions and mitigation:

## Cost And Capacity

- Expected cost per request (before → after):
- Expected daily / monthly cost (before → after):
- Rate limits and quota implications:
- Budget alert thresholds updated: yes / no

## Safety, Privacy, Compliance

- [ ] Data sent to provider matches data classification policy.
- [ ] DPA / sub-processor list reviewed and customer notification handled if required.
- [ ] Region / data residency requirements satisfied.
- [ ] Output safety guardrails re-tested.

## Rollout Plan

- Strategy: shadow / canary / A/B / staged % rollout
- Cohort and ramp schedule:
- KPIs and stop rules:
- Rollback path (previous model + snapshot, config revert):

## Sign-Off

- Engineering:
- Product:
- Security / privacy / compliance (as applicable):
- Date:
