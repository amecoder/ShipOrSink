---
paths:
  - "**/audit/**"
  - "**/auth/**"
  - "**/access/**"
  - "**/*audit*"
  - "**/*Audit*"
  - "**/*compliance*"
  - "**/logging/**"
  - "**/migrations/**"
  - "docs/compliance/**"
---

# Compliance & Audit Readiness Rules

Apply these rules whenever the system handles regulated data (PII, PHI, payment, financial) or operates under SOC 2, ISO 27001, GDPR, HIPAA, PCI DSS, or sector-specific frameworks.

## Access Control

- Production access uses SSO + MFA. Local long-lived credentials are forbidden.
- Privileged access (prod DB, infra console, secret stores) is just-in-time with approval logs and time-bound elevation.
- Access reviews happen on a defined cadence (quarterly minimum); leavers are deprovisioned within the agreed SLA and the action is recorded.
- Service accounts have owners, scopes, rotation policy, and lifecycle ownership.

## Audit Logging

- Security-relevant events (authn, authz changes, role changes, data export, admin actions, PII access, config changes, feature flag flips) are logged with actor, timestamp, target, action, request ID, and outcome.
- Audit logs are tamper-evident (append-only, signed, or shipped to a separate account/store), retained per policy, and protected by least-privilege read access.
- Logs include enough context to answer: who did what, to which resource, on whose behalf, and from where.

## Change Management

- Production changes go through PR with required reviewers, CI gates, and traceable issue/ticket linkage.
- Emergency changes follow a documented break-glass process and are reviewed within an agreed window after the fact.
- Deployment trail (who deployed what, when, with which artifact hash) is preserved for the audit retention period.
- Schema and infra changes are reviewed against the relevant readiness checklist (RDBMS schema, release readiness, NoSQL adoption, distributed SQL).

## Vendor And Sub-Processor Management

- New vendors with access to data require a documented risk review (security questionnaire, certifications, DPA, sub-processor list, region).
- Vendor changes (new sub-processor, region change, scope change) trigger re-review and customer notification per contract.
- Vendor inventory is kept current with owner, scope, data shared, criticality, and renewal date.

## Data Lifecycle And Privacy

- Data classification, retention, and deletion follow `privacy-data-governance.md` and the data retention policy.
- DSR (Data Subject Request) workflows for access, export, and deletion are documented, tested, and time-bounded to legal SLAs.
- PII flow is mapped (collection, processing, storage, sub-processors, cross-border) and updated when systems change.
- Backups have the same access, encryption, and retention discipline as primary data.

## Encryption And Secrets

- Data at rest is encrypted with managed KMS; keys are rotated on policy.
- Data in transit uses TLS 1.2+; internal traffic uses mTLS or equivalent where required.
- Secrets are stored in a dedicated secret manager; pre-commit and CI block secret leaks.
- Production secrets are not present in dev environments or shared notebooks.

## Evidence Generation

- Required evidence (access reviews, vendor reviews, change logs, alert tests, backup restore tests, incident postmortems, training records) is produced as part of normal operations and stored in a known location.
- Each control owner can answer "show me the last 90 days of evidence" in minutes, not days.

## Review Checklist

- Access, audit, change, vendor, data, encryption controls are mapped to the framework(s) the company is in scope for.
- Evidence is generated automatically where possible (CI logs, IdP logs, ticketing exports).
- A control gap or failed evidence run opens a tracked issue with owner and due date.
- Customers' DPA / security commitments are tracked against current implementation.
- Compliance and audit readiness do not bypass the engineering quality gates; they extend them.
