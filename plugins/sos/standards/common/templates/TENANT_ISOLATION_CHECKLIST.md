# Tenant Isolation Checklist

Use this checklist for multi-tenant products, workspaces, organizations, or projects.

## Tenant Model

- Tenant unit:
- Tenant identifier:
- Owner:
- Isolation strategy:

## Data Access

- [ ] Tenant context is established at the boundary.
- [ ] Tenant id cannot be trusted from unauthenticated client input.
- [ ] Repository/query layer enforces tenant filtering.
- [ ] Search, exports, reports, and background jobs preserve tenant context.
- [ ] Cross-tenant admin access is explicitly authorized and audited.

## Tests

- [ ] Read isolation test.
- [ ] Write isolation test.
- [ ] Search/export isolation test.
- [ ] Background job isolation test.
- [ ] Admin/support bypass test.

## Operations

- [ ] Logs include tenant context where safe.
- [ ] Metrics can attribute traffic/cost by tenant where practical.
- [ ] Rate limits or quotas prevent noisy neighbors.
- [ ] Tenant delete/export behavior is documented.

## Exceptions

-
