# Layered Architecture Checklist

Use this checklist for new modules, large refactors, and AI-generated feature slices.

## Module

- Module:
- Owner:
- Feature or domain:
- Related task/spec:

## Dependency Direction

- [ ] Presentation depends on application contracts only.
- [ ] Application depends on domain and ports.
- [ ] Domain has no framework, HTTP, ORM, queue, or environment dependencies.
- [ ] Infrastructure implements ports.
- [ ] Shared code has no feature-module dependency.

## Boundary Objects

- [ ] Request/response DTOs stay at API/UI boundaries.
- [ ] Persistence models stay in infrastructure.
- [ ] Domain objects express business language.
- [ ] Mappers are located at layer boundaries.

## Tests

- [ ] Domain tests run without framework bootstrapping.
- [ ] Application tests use fake ports or controlled integration tests.
- [ ] Infrastructure adapters have integration or contract tests.
- [ ] API/UI tests cover validation and user-facing errors.

## Exceptions

List any intentional layer violation and why it is acceptable:

-
