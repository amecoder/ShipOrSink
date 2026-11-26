---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "k8s/**"
  - "helm/**"
  - "**/Dockerfile*"
  - "**/docker-compose*.{yml,yaml}"
  - "**/llm*/**"
  - "**/ai/**"
  - "**/billing/**"
  - "**/infra/**"
  - "**/infrastructure/**"
  - "docs/cost/**"
---

# Cost Governance Rules

Engineering decisions must make recurring cost visible before production release.

## Cost Ownership

- Every production service, database, queue, AI workflow, and scheduled job needs an owner and cost center or team tag.
- New infrastructure must include expected monthly cost, scaling driver, and cost guardrail.
- Use tags/labels for environment, service, team, owner, and managed-by.
- Delete unused environments, buckets, indexes, queues, dashboards, and feature-flagged experiments.

## AI/LLM Cost

- Estimate token, transcription, embedding, rerank, image, and storage costs before enabling AI features.
- Add per-request budget, timeout, retry cap, and fallback behavior.
- Track model, provider, prompt version, input/output tokens, latency, cache hit rate, and error rate.
- Use cheaper models, batching, caching, summarization, or distillation only when quality gates remain acceptable.

## Data And Infrastructure Cost

- Indexes, replicas, retention, backups, and analytics exports must have an owner and retention target.
- Load tests should estimate capacity and cost for expected traffic.
- Autoscaling limits must prevent accidental runaway spend.
- Alerts should cover abnormal spend, token spikes, queue backlogs, and storage growth.

## Review Checklist

- Cost estimate and owner are documented.
- Observability can attribute cost to service, tenant, feature, or model where practical.
- Runaway spend guardrails exist.
- Retention and cleanup policies are defined.
- High-cost changes have a rollback or kill-switch.
