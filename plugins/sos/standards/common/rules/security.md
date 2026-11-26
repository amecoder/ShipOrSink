# Security Rules (All Languages)

These rules apply to ALL files in the project.

## Secrets Management

- NEVER hardcode secrets (API keys, passwords, tokens, connection strings)
- Use environment variables or secret managers (AWS Secrets Manager, HashiCorp Vault)
- `.env` files must be in `.gitignore`
- Provide `.env.example` with placeholder values

## Input Validation

- Validate ALL user input at system boundaries (API handlers, form inputs)
- Use schema validation libraries (Pydantic, Zod, Bean Validation)
- Sanitize HTML output to prevent XSS
- Use parameterized queries to prevent SQL injection

## Authentication / Authorization

- Verify auth on every endpoint (no security by obscurity)
- JWT: short-lived access tokens (15min), refresh token rotation
- Passwords: bcrypt/argon2 with salt (never MD5/SHA-1)
- API keys: rotate regularly, scope to minimum permissions
- Rate limiting on authentication endpoints

## Error Handling

- User-facing errors: safe generic message
- Internal logs: detailed error with stack trace
- Never expose stack traces, SQL errors, or internal paths to users

## Dependencies

- Run dependency vulnerability scans in CI (Trivy, Snyk, govulncheck)
- Keep dependencies updated (Dependabot/Renovate)
- Pin dependency versions (lockfiles committed)

## Gates

- `security-review` (Semgrep + Gitleaks + Trivy) is a required status check on the PR; a finding blocks the merge until fixed or explicitly accepted by a human with a documented reason.
- Local pre-commit runs gitleaks/detect-secrets before the commit exists; CI re-scans the full history.
- Security-sensitive changes (auth, secrets handling, input parsing, crypto, permissions) get the `security` label and an independent security review (a second reviewer or model) in addition to the automated gate.

## Forbidden

- Hardcoded credentials in source code
- `eval()` or dynamic code execution with user input
- Disabled SSL/TLS verification
- `console.log` / `print` of sensitive data
- Committing .env files, private keys, certificates
