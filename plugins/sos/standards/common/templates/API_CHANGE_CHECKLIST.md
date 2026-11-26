# API Change Checklist

Use this checklist before changing public APIs, internal service APIs, or event contracts.

## Change

- API/contract:
- Owner:
- Consumers:
- Related issue/design doc:

## Compatibility

- [ ] Contract file is updated: OpenAPI, AsyncAPI, GraphQL schema, or Protobuf.
- [ ] Change is backward compatible.
- [ ] Breaking changes have a migration path and deprecation date.
- [ ] Generated clients, SDKs, or mocks are updated.
- [ ] Contract tests are updated.

## Security And Privacy

- [ ] Auth and authorization behavior is documented.
- [ ] Rate limits and quotas are documented.
- [ ] Sensitive fields are classified.
- [ ] Error responses do not leak internals.

## Operations

- [ ] Metrics/logs/traces include the new path/event where relevant.
- [ ] Rollout and rollback plan are documented.
- [ ] Consumer communication is prepared.

## Verification

```bash
# Contract validation command
```

- Result:
