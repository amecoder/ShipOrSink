# Compliance & Audit Readiness Guide

## Goal

Operate so that an audit (SOC 2, ISO 27001, GDPR, HIPAA, PCI DSS, sector-specific) is a routine evidence collection, not a scramble. Bake controls into the engineering workflow rather than bolting them on quarterly.

## Mindset

Compliance is the documented version of how you already operate. If you have to invent the practice during the audit, you have already failed. The goal is "we always do this, here is the trail."

## Control Areas

- Access control (who can do what, in production and dev).
- Audit logging (what happened, by whom, when, with what outcome).
- Change management (every prod change traced to a PR, ticket, reviewer).
- Vendor and sub-processor management (who processes our data, with what scope).
- Data lifecycle and privacy (classification, retention, deletion, DSRs).
- Encryption and secrets (at rest, in transit, in storage, in CI).
- Evidence generation (logs, exports, snapshots, restore tests).

## Access Control

- SSO + MFA for production access. No long-lived local credentials.
- Privileged access (prod DB, infra console, secret stores) is just-in-time, time-bound, with approval logs.
- Quarterly access reviews using the Access Review template.
- Service accounts have owners, scopes, rotation policies.

## Audit Logging

- Cover authn, authz changes, admin actions, regulated data access / mutation, security events, and operational events (deploys, infra, schema).
- Schema includes actor, target, action, outcome, request_id, timestamps, and before / after for sensitive changes.
- Storage is append-only or signed; separate from application logs; least-privilege read.
- Drill: pick a recent admin action and reconstruct it from audit logs alone.

## Change Management

- Every production change goes through PR with required reviewers, CI gates, and a ticket reference.
- Emergency changes follow a documented break-glass with after-the-fact review within an agreed window.
- Deploy trail (who, what, when, artifact hash) is preserved for the audit retention period.
- Schema and infra changes follow the Release Readiness Checklist.

## Vendor And Sub-Processor

- New vendors with data access fill the Vendor Risk template.
- Material changes (region, sub-processor, scope) trigger re-review.
- Vendor inventory is current; renewal and review dates tracked.

## Data Lifecycle And Privacy

- Data classification + retention + deletion follow the privacy-data-governance rule and Data Retention Policy.
- DSR (access, export, delete) workflows are documented, tested, and time-bounded to legal SLAs (e.g., 30 days for GDPR).
- PII flow is mapped: collection → processing → storage → sub-processors → cross-border.
- Backups have the same access, encryption, and retention discipline as primary data.

## Encryption And Secrets

- Data at rest encrypted with managed KMS; key rotation on policy.
- TLS 1.2+ in transit; mTLS or equivalent for sensitive internal traffic.
- Secrets in a dedicated manager. Pre-commit and CI block secret leaks.
- No production secrets in dev or notebooks.

## Evidence Generation

- Generate evidence as a side effect of normal operations, not as a special task.
  - IdP exports for access and MFA enforcement.
  - PR + CI logs for change management.
  - Audit log slices for admin actions and DSRs.
  - Backup restore test results.
  - Incident postmortems and on-call handoffs.
  - Training completion records.
  - Vendor inventory snapshots.
- Each control owner can answer "show me the last 90 days of evidence" in minutes.

## Anti-Patterns

- Audit-time scrambles to pull screenshots manually.
- "Compliance team owns this" without engineering ownership of controls.
- Long-lived shared admin accounts.
- Production secrets in `.env.dev`, Slack messages, or notebooks.
- Audit logs that record events but cannot be queried by actor or target in under a minute.

## Adoption Sequence

1. Inventory controls required by your in-scope frameworks and contractual commitments.
2. Map each control to engineering reality (already in place vs gap).
3. Close gaps with the smallest change that produces evidence (turn on IdP audit log export, require PR reviewers, etc.).
4. Move evidence generation into automated pipelines (S3 bucket, evidence collector, vendor inventory tool).
5. Run an internal mini-audit: pick five controls, ask owners for evidence, time the response.
6. Iterate on the slowest five.

## References

- AICPA Trust Services Criteria (SOC 2).
- ISO/IEC 27001:2022.
- GDPR text and EDPB guidelines.
- HIPAA Security Rule.
- PCI DSS v4.
- NIST SP 800-53 control families.
