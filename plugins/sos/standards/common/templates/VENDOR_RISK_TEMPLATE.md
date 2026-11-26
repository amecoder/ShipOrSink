# Vendor / Sub-Processor Risk Review Template

Use this template before onboarding a new vendor that processes customer data, regulated data, or supports a critical operational path. Re-run on material changes (region, sub-processor, scope, contract).

## Metadata

- Vendor name:
- Service description:
- Data shared (categories + classification):
- Region(s) of processing:
- Owner (internal):
- Date:
- Status: under review / approved / approved with conditions / rejected / retired

## Business Context

- Use case / replacement for:
- Criticality (low / medium / high / critical):
- Volume of data / requests:
- Contract / commercial owner:

## Security Posture

- Certifications (SOC 2 Type II, ISO 27001, HIPAA, PCI DSS, etc.) — link to reports:
- Last security questionnaire / assessment date:
- Penetration test cadence and last report date:
- Encryption at rest / in transit:
- Authentication options (SSO, SCIM, MFA enforcement):
- Sub-processors list and notification policy:

## Privacy And Compliance

- Data Processing Agreement signed and stored:
- Data classification matched against vendor's allowed data:
- Cross-border transfer mechanism (SCCs, adequacy, intra-group):
- Retention and deletion behavior on contract end:
- Customer notification triggers (sub-processor change, region change):

## Operational Risk

- SLA and error budget alignment with our SLO:
- Incident notification SLA:
- Status page / outage history:
- Lock-in risk and exit plan (export, replace, migrate):

## Integration Risk

- Authentication scope and least-privilege evaluation:
- Allowlist / denylist configuration:
- Logging of vendor-side actions back to our audit log:
- Failure mode if vendor is down (fail-closed / fail-open / degraded):

## Decision

- [ ] Approved
- [ ] Approved with conditions:
- [ ] Rejected (reason):
- Compensating controls (if any):
- Re-review date:

## Sign-Off

- Engineering owner:
- Security:
- Privacy / Legal:
- Finance / Procurement (as applicable):
