# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest | yes |

## Reporting A Vulnerability

Report vulnerabilities privately to:

- Email:
- Security contact:
- Expected first response:

Do not open a public issue for suspected vulnerabilities.

## Security Requirements

- No hardcoded secrets.
- Validate all external input.
- Use parameterized database queries.
- Sanitize user-controlled HTML.
- Enforce authentication and authorization at boundaries.
- Use least privilege for cloud, database, and CI permissions.
- Scan dependencies and containers in CI.

## Incident Handling

- Triage severity.
- Mitigate customer impact.
- Rotate affected secrets.
- Patch and release.
- Publish advisory when appropriate.
- Complete postmortem for high-severity incidents.

## Disclosure

- Disclosure timeline:
- CVE process:
- Customer notification owner:
