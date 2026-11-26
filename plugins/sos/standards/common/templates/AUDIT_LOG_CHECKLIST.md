# Audit Log Checklist

Use this checklist for any system that handles regulated data, financial transactions, or operates under SOC 2 / ISO 27001 / GDPR / HIPAA / PCI DSS.

## Coverage

- [ ] Authentication events: success, failure, MFA challenge, lockout.
- [ ] Authorization changes: role grant / revoke, group membership change, scope change.
- [ ] Admin actions: configuration changes, feature flag flips, user impersonation, data export.
- [ ] Data access on regulated entities: PII / PHI / payment / billing reads where applicable.
- [ ] Data mutation on regulated entities: writes, bulk updates, deletions.
- [ ] Security events: failed authz, suspicious patterns, integration revocation, secret rotation.
- [ ] Operational events: deploys, infra changes, schema migrations.

## Event Schema

- [ ] timestamp (UTC, ISO 8601, monotonically increasing within source)
- [ ] actor (user_id, service_id, on_behalf_of)
- [ ] actor_context (ip, user_agent, region, session_id, request_id)
- [ ] target (resource type + id; tenant id if multi-tenant)
- [ ] action (verb, namespace)
- [ ] outcome (success / failure / partial)
- [ ] reason (free-text or code, especially for failures and authz denials)
- [ ] before / after for sensitive changes (with PII redaction where required)
- [ ] correlation IDs to join with application logs and traces

## Integrity And Storage

- [ ] Append-only storage or signed log chain.
- [ ] Separate account / project / bucket from application logs.
- [ ] Read access is least privilege; write access only from the audit pipeline.
- [ ] Retention period matches policy (legal, contractual, framework).
- [ ] Tamper detection (hash chain, write-once storage, periodic integrity checks).

## Privacy

- [ ] PII fields are minimized; sensitive fields are tokenized or hashed.
- [ ] Subject access / DSR workflow can produce relevant audit slices without exposing other tenants.
- [ ] Cross-border storage matches data residency commitments.

## Operational Hygiene

- [ ] Volume and lag of the audit pipeline is monitored; alerts on drop or stall.
- [ ] Schema changes go through the same review as application schemas.
- [ ] Sample queries answer "who did what to X between A and B" without engineering help.
- [ ] Periodic drill: pick a recent admin action and reconstruct it from audit logs only.

## Evidence For Auditors

- [ ] Documented log inventory (sources, schema, retention).
- [ ] Sample export for a defined window.
- [ ] Access logs to the audit log store itself.
- [ ] Integrity test results (hash verification, restore test).

## Open Items

-
