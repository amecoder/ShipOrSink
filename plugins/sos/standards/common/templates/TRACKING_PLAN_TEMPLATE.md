# Tracking Plan Template

The tracking plan is the single source of truth for analytics events. Update this file in the same PR as the schema and code change.

## Metadata

- Owner team:
- Last reviewed:
- Storage / warehouse location:
- Schema enforcement (e.g., JSON Schema, dbt, semantic layer):

## Identifiers

| ID | Type | Source | Notes |
|----|------|--------|-------|
| user_id | uuid | auth | stable across devices |
| anonymous_id | uuid | client SDK | pre-auth |
| session_id | uuid | client SDK | rotates on idle/login |
| tenant_id | uuid | server | for B2B / multi-tenant |
| request_id | uuid | server | for joining with logs |

## Naming Convention

- Format: `<object>_<action>` in past tense (e.g., `signup_completed`, `checkout_started`).
- Properties in `snake_case`.
- Times in ISO 8601 UTC.
- Money in minor units + currency code.

## Events

| Event name | Trigger | Source | Owner | PII flag | Required props | Optional props | Status |
|------------|---------|--------|-------|----------|----------------|----------------|--------|
| signup_started | user submits email | client | Growth | none | source, plan_id | utm_*, device | active |
| signup_completed | account created | server | Growth | hashed email | user_id, plan_id, source | utm_* | active |
| checkout_started | user enters checkout | server | Payments | none | user_id, cart_id, total_minor, currency | coupon_id | active |
| checkout_completed | payment authorized | server | Payments | none | user_id, order_id, total_minor, currency, payment_method | coupon_id | active |
|  |  |  |  |  |  |  |  |

## Property Catalog

| Property | Type | Allowed values / format | PII | Notes |
|----------|------|-------------------------|-----|-------|
| user_id | uuid | RFC 4122 | yes (linkable) | hashed in warehouse |
| email | string | RFC 5322 | yes | only server-side, hashed before warehouse |
| plan_id | string | enum | no |  |
| total_minor | integer | minor units (e.g., cents) | no |  |
| currency | string | ISO 4217 | no |  |
| utm_source | string | free text | no | normalize lowercase |
|  |  |  |  |  |

## Privacy And Consent

- Consent state required before sending any event from regions:
- Opt-out behavior:
- Cross-border data flows:

## Quality Gates

- [ ] JSON schema or contract test enforces required properties and types.
- [ ] Bad payloads land in a quarantine / DLQ topic, not silently dropped.
- [ ] Volume + schema rejection rate has alerts.
- [ ] Server-side and client-side event reconciliation for revenue / conversion.

## Change Process

- Add or change event: PR updates this plan, schema, code, and dashboards in the same change.
- Deprecate event: mark `status = deprecated`, set removal date, notify consumers, then remove after window.
- Backfills are explicit, logged, and tested in staging.
