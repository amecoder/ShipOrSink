---
paths:
  - "**/evals/**"
  - "**/eval/**"
  - "**/golden/**"
  - "**/goldens/**"
  - "**/*eval*"
  - "**/*Eval*"
  - "**/prompts/**"
  - "**/benchmarks/**"
  - "docs/evals/**"
---

# AI Eval Harness Rules

AI features need repeatable evaluation in addition to unit and integration tests. Evals protect prompts, retrieval, tool calls, and model/provider changes.

## When Required

- LLM prompt, system instruction, routing, tool use, retrieval, ranking, transcription, summarization, extraction, or agent workflow changes.
- Model, provider, embedding model, vector index, chunking strategy, or temperature changes.
- Any AI output that affects user decisions, stored data, billing, security, or external communication.

## Eval Set

- Keep a versioned dataset with representative happy paths, edge cases, and failure cases.
- Include expected output shape, refusal/fallback criteria, and scoring rubric.
- Redact or synthesize private data.
- Track model, provider, prompt version, retrieval config, and test date.

## Gates

- Deterministic tests validate schema, parser, fallback, and error handling.
- Eval harness reports quality, latency, and cost.
- Regression threshold is defined before changing prompts or models.
- Human review is required for high-impact prompts and judge rubrics.

## Handoff

- Record eval command, dataset version, pass/fail summary, notable regressions, and accepted risks.
