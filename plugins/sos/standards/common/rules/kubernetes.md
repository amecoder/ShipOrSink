---
paths:
  - "k8s/**/*.yml"
  - "k8s/**/*.yaml"
  - "helm/**"
  - "**/kustomization.yaml"
  - "**/kustomization.yml"
---

# Kubernetes Rules

- All resources must have labels: `app`, `version`, `environment`, `team`
- Resource requests AND limits on every container
- Liveness and readiness probes on every deployment
- Use namespaces for environment isolation
- Never use `latest` tag — pin image versions with SHA or semver
- NetworkPolicy for pod-to-pod communication control
- PodDisruptionBudget for high-availability workloads
- Secrets via External Secrets Operator or Sealed Secrets (not plain Secret)

## Security

- `securityContext.runAsNonRoot: true`
- `securityContext.readOnlyRootFilesystem: true`
- `securityContext.allowPrivilegeEscalation: false`
- No `hostNetwork`, `hostPID`, `hostIPC` unless justified
- Use ServiceAccount with minimal RBAC permissions

## Naming

- Resources: `<app>-<component>-<resource>` (e.g., `myapp-api-deployment`)
- Namespaces: `<team>-<env>` (e.g., `platform-prod`)
- ConfigMaps/Secrets: `<app>-<purpose>` (e.g., `myapp-config`)

## Forbidden

- `kubectl apply` directly to production (use GitOps: ArgoCD/Flux)
- Plain text Secrets in manifests (use SealedSecrets or ExternalSecrets)
- `kubectl delete namespace` without confirmation
- Wildcard RBAC permissions (`*`)
