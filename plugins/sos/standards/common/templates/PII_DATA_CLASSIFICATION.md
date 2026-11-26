# PII Data Classification

Use this document to classify personal or sensitive data before implementation.

## Classification Levels

| Level | Meaning | Examples | Default Controls |
|-------|---------|----------|------------------|
| Public | Safe to disclose | Public docs, marketing content | Integrity controls |
| Internal | Business-only | Internal metrics, non-sensitive configs | Authenticated access |
| Confidential | User or business sensitive | Email, transcript, meeting notes, account ids | Encryption, least privilege, audit |
| Restricted | High-risk or regulated | Payment, auth secrets, government ids, health data | Strong isolation, approval, strict retention |

## Data Categories

| Field/Data | Level | Purpose | Source | Stored In | Shared With | Retention |
|------------|-------|---------|--------|-----------|-------------|-----------|
| | | | | | | |

## AI/LLM Handling

- [ ] Data may be sent to approved AI provider.
- [ ] Provider retention/training settings are documented.
- [ ] Prompt and response logs are redacted or disabled.
- [ ] User consent or product notice is handled.
- [ ] Outputs are validated before storage or display.

## Logging And Analytics

- [ ] PII is not logged.
- [ ] Analytics events use stable pseudonymous identifiers when possible.
- [ ] Support tooling redacts sensitive fields.
- [ ] Local development uses synthetic or anonymized data.

## Approval

- Owner:
- Security/privacy reviewer:
- Date:
