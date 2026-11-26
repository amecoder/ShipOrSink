# LLMOps / PromptOps Governance Guide

## Goal

Treat AI features (LLM, embedding, vision, speech, agent, RAG) the same way mature teams treat services: versioned, evaluated, observable, budgeted, and reversible.

## Why This Matters

A prompt change is a behavior change. A model snapshot rev is a behavior change. They affect users, support volume, conversion, safety, and cost in ways that ad-hoc tweaks cannot recover from. Without LLMOps discipline, AI features fail silently — bad outputs blend into the user experience until support tickets pile up or a regulator asks how you control this.

## Versioning

- Store prompts, system instructions, tool / function schemas, and agent graphs in source control with semantic file names and version IDs (e.g., `prompts/checkout/triage_v3.yaml`).
- Change them through PR with diff, owner, rationale, eval result.
- Models, providers, temperature, top-p, max tokens, safety, tools are config — versioned and environment-pinned. No hardcoding.
- Pin model snapshots in production. "Latest" aliases drift silently.

## Evaluation Before Release

- Every prompt or model change runs the project eval harness (see `eval-driven-development-guide.md` and `ai-eval-harness.md`).
- Required suites: golden cases, regression cases, adversarial / jailbreak, hallucination / factuality, latency, cost.
- Attach eval result to the PR. Score regression blocks merge unless explicitly accepted with reason and owner.
- Human review is required for changes affecting safety, tone, or factual claims.

## Runtime Telemetry

Per call, log:

- prompt_template_id + version
- model + snapshot
- latency, input_tokens, output_tokens, cost
- request_id, user_id / tenant_id, route, env
- guardrail outcomes (toxicity, schema-validation, policy)

Aggregate: tokens / cost / latency by route, by tenant, by prompt version, by model. This is what makes regressions debuggable.

## Safety Controls

- Output guardrails: schema validation (JSON output), toxicity / policy classifier, refusal patterns.
- Prompt-injection defenses for any flow ingesting untrusted input: system / tool isolation, escape characters, input length and format limits.
- Tool / function calls: allowlist, server-side validation, separate authz scope for destructive tools.
- PII redaction or tokenization before logging prompts and responses.

## Cost And Reliability Budgets

- Cost per request and cost per day budgets per AI feature; alerts before breach.
- p50 / p95 latency targets per endpoint, per model.
- Documented degraded mode (smaller context, smaller model, cached response, refusal) when budget or latency breaches occur.

## Release And Rollback

- Progressive rollout: shadow → canary → A/B → full.
- KPI gates (CSAT, deflection, conversion, error rate) and eval gates both must pass.
- Rollback = revert to previous prompt version + previous model snapshot, in one config change.
- Replay failing inputs against the prior version after an incident to confirm regression scope.

## Privacy And Compliance

- Match data sent to providers against the data classification.
- DPA, sub-processor list, region, and customer notification policies are tracked as part of vendor risk review.
- Eval datasets must not contain PII or secrets.

## Common Anti-Patterns

- Prompt embedded as a string literal in production code, edited in place, no diff.
- Model auto-upgraded by the provider because of a "latest" alias.
- No telemetry on token / cost; surprise bill at month end.
- Eval suite that only contains "happy path" examples and one cherry-picked jailbreak.
- Tool functions exposed to the LLM with no server-side validation.

## Adoption Steps If You Are Starting

1. Move all prompts and config out of code into versioned files.
2. Add request-level telemetry (ids, tokens, cost, latency, route).
3. Build a 20-case eval suite (10 golden, 5 regression, 5 adversarial). Wire it to CI.
4. Pin model snapshots in production.
5. Add cost and latency budgets with alerts.
6. Document rollback and degraded modes for the top AI feature.
7. Iterate: grow eval suite, add safety guardrails, formalize prompt / model change templates.

## References

- OpenAI, "Production Best Practices for OpenAI Models" (provider docs).
- Anthropic, "Designing Evaluations for LLM Applications" (provider docs).
- ISO/IEC 42001, "AI Management Systems".
- NIST AI Risk Management Framework, https://www.nist.gov/itl/ai-risk-management-framework .
