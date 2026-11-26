# Eval-Driven Development Guide

## Goal

AI features need evals because unit tests alone do not catch prompt, model, retrieval, ranking, and tool-use regressions.

## When to Add Evals

- LLM prompts or system instructions change.
- Model, provider, temperature, or routing changes.
- RAG chunking, embedding model, retriever, reranker, or vector index changes.
- Transcription, summarization, extraction, classification, or agent workflows affect user outcomes.

## Eval Layers

| Layer | Purpose |
|-------|---------|
| Unit tests | Schema, parser, fallback, deterministic utilities |
| Golden cases | Known inputs with expected behavior |
| Rubric scoring | Quality evaluation for open-ended outputs |
| Regression set | Prevent known failures from returning |
| Cost/latency checks | Protect operational budget |

## Minimum Harness

- Versioned dataset.
- Expected output shape or rubric.
- Scoring command.
- Thresholds that block release.
- Logged prompt, model, retrieval config, cost, and latency.

## Release Gate

- Quality does not regress beyond threshold.
- Schema pass rate is acceptable.
- Fallback/refusal behavior is tested.
- Cost and latency are within budget.
- Human review signs off high-impact outputs.

## References

- OpenAI Codex usage guide: https://openai.com/business/guides-and-resources/how-openai-uses-codex/
- OpenAI prompt engineering best practices: https://help.openai.com/en/articles/6654000-best-practices-for-prompt-engineering-with-openai-api
