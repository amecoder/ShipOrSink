---
paths:
  - "**/tenant*/**"
  - "**/*tenant*"
  - "**/*Tenant*"
  - "**/middleware/**"
  - "**/auth/**"
  - "**/migrations/**"
  - "**/repositories/**"
  - "**/rls/**"
---

# Multi-Tenancy Rules

Use these rules when one system serves multiple customers, workspaces, organizations, teams, or projects.

## Tenant Model

- Define the tenant unit explicitly: organization, workspace, account, project, or environment.
- Every tenant-scoped entity must carry a tenant identifier or be reachable only through a tenant-owned aggregate.
- Tenant context must be established at the boundary and passed explicitly through the request/job flow.
- Avoid relying on client-provided tenant ids without authorization checks.

## Isolation

- Choose and document isolation level: shared schema, schema per tenant, database per tenant, or account per tenant.
- Enforce tenant filtering in repositories, query builders, ORM scopes, or row-level security.
- Tests must cover cross-tenant access denial.
- Admin/support bypasses require explicit approval, audit logging, and least privilege.

## Operations

- Metrics, logs, traces, rate limits, quotas, and billing dimensions should include tenant context where safe.
- Backups, exports, deletes, and migrations must define tenant-level behavior.
- Avoid noisy-neighbor risk through quotas, rate limits, workload isolation, or capacity controls.

## Review Checklist

- Tenant boundary is named.
- Data access cannot cross tenant boundaries by default.
- Background jobs and async consumers preserve tenant context.
- Support/admin access is auditable.
- Tests prove isolation for reads, writes, search, exports, and background processing.
