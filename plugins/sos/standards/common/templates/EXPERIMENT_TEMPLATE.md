# Experiment Template

Use this template before launching any controlled experiment (A/B test, multi-arm test, holdout, switchback).

## Metadata

- Experiment name / ID:
- Owner (PM + Eng):
- Linked PRD / Feature Spec:
- Start date / planned end date:

## Hypothesis

- We believe \_\_\_ for \_\_\_ users will cause \_\_\_ to change because \_\_\_.
- Expected direction and magnitude:

## Design

- Unit of randomization (user / device / session / tenant):
- Bucketing key and platform (e.g., feature flag service):
- Variants and traffic allocation (e.g., control 50% / treatment 50%):
- Mutual exclusion with other live experiments:
- Inclusion / exclusion rules (region, plan, role, fraud):

## Metrics

| Type | Metric | Definition link | Direction | MDE | Source |
|------|--------|-----------------|-----------|-----|--------|
| Primary | | | up / down |  |  |
| Secondary | | | | | |
| Guardrail | latency p95 |  | up bad | | |
| Guardrail | error rate |  | up bad | | |
| Guardrail | revenue per user |  | down bad | | |

## Sample Size And Duration

- Baseline rate / mean:
- Required sample size (per variant):
- Expected daily traffic:
- Expected duration:
- Stop rules (early stop, harm detected, MDE reached):

## Analysis Plan

- Pre-registered analysis method (frequentist / Bayesian / sequential):
- Multiple testing correction (if any):
- Subgroup / segment analysis (declared in advance):
- Reviewer for results:

## Risks And Safeguards

- User harm risk:
- Revenue / business risk:
- Legal / privacy risk:
- Mitigation (kill switch, holdout, manual override):

## Launch Checklist

- [ ] Tracking plan covers required metrics.
- [ ] Experiment platform configured and verified with a smoke test.
- [ ] Guardrail alerts in place.
- [ ] Internal dogfood / bug-bash done.
- [ ] Customer support / sales / ops informed.

## Result (filled after experiment)

- Outcome on primary metric (with CI / posterior):
- Guardrail outcomes:
- Decision: ship / hold / iterate / kill
- Learnings:
- Follow-up actions:
- Archive link (notebook, query, dashboard snapshot):
