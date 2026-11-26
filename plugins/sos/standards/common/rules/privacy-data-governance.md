---
paths:
  - "**/models/**"
  - "**/entities/**"
  - "**/migrations/**"
  - "**/*.sql"
  - "**/auth/**"
  - "**/users/**"
  - "**/user/**"
  - "**/analytics/**"
  - "**/tracking/**"
  - "**/logging/**"
  - "**/*pii*"
  - "**/*PII*"
  - "**/*consent*"
  - "docs/privacy/**"
---

# Privacy And Data Governance Rules

Any product that accepts user text, audio, transcripts, files, identifiers, or analytics data must make data handling explicit.

## Data Classification

- Classify data as public, internal, confidential, restricted, or regulated before storing it.
- Treat audio, transcripts, meeting notes, prompts, uploaded files, auth data, payment data, and precise identifiers as sensitive by default.
- Keep a data inventory for sources, storage locations, derived stores, processors, retention, and owners.
- Do not collect data without a named product, legal, or operational purpose.

## Retention And Deletion

- Define retention period, deletion trigger, backup behavior, and legal hold behavior for every sensitive data category.
- Support user deletion requests where product and legal requirements require it.
- Derived data must have a rebuild or deletion story.
- Logs, traces, analytics events, and model prompts must not become accidental permanent storage.

## Access And Sharing

- Use least-privilege access for production data.
- Production data access must be logged and reviewable.
- Do not use raw production PII in local development, demos, screenshots, or tests.
- Third-party processors require documented purpose, data categories, region, retention, and deletion process.

## AI/LLM Data Handling

- Do not send restricted data to an AI provider unless the provider, contract, retention setting, and user consent model are approved.
- Prompt logs must be redacted or disabled for sensitive workflows.
- Store prompt/response traces only when retention, access control, and deletion are defined.
- Validate AI outputs before displaying, storing, or using them in downstream decisions.

## Review Checklist

- Data categories and owners are documented.
- Retention and deletion are defined.
- PII is redacted from logs, traces, analytics, and support tooling.
- AI provider data handling is documented when applicable.
- Security review is required for new restricted or regulated data flows.
