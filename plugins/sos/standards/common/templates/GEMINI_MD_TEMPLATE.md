# GEMINI.md

This file adapts the shared project rules for Gemini CLI.

## Shared Rules

Use `AGENTS.md` as the main source of truth for project rules. If Gemini is configured with `.gemini/settings.json`, set `context.fileName` to `["AGENTS.md", "GEMINI.md"]` so all agents read the same project standard (current Gemini CLI documents only `context.fileName`; the flat `contextFileName` key belongs to the legacy settings format).

## Gemini Role

- Research current library behavior, external docs, and alternative designs.
- Summarize long documents and compare tradeoffs.
- Review PRD, Feature Spec, architecture, prompts, and data decisions.
- Produce concise recommendations with evidence and links when external sources are used.

## Boundaries

- Do not edit production code unless ownership is explicitly assigned.
- Do not introduce dependencies, databases, external services, or model/provider changes without a decision record.
- Do not include secrets, customer data, or private prompts in analysis.

## Output Contract

When reviewing or researching, include:

- Question answered.
- Sources or files inspected.
- Recommendation.
- Risks and unknowns.
- Follow-up actions for Codex or Claude Code.
