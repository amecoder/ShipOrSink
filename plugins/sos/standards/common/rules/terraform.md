---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/.terraform.lock.hcl"
---

# Terraform Rules

- `terraform fmt` on all files before commit
- All resources must have tags: `Name`, `Environment`, `Team`, `ManagedBy=terraform`
- Variables: use `description`, `type`, and `validation` blocks
- Outputs: use `description` for all outputs
- Use `terraform validate` before plan
- Module naming: `terraform-<PROVIDER>-<NAME>`
- State: remote backend (S3/GCS) with locking (DynamoDB/GCS)
- Never commit .tfstate files

## File Structure

```
modules/
  <module-name>/
    main.tf          # Resources
    variables.tf     # Input variables
    outputs.tf       # Output values
    versions.tf      # Provider/terraform version constraints
environments/
  dev/
  staging/
  prod/
```

## Naming

- Resources: `snake_case` (e.g., `aws_s3_bucket.app_data`)
- Variables: `snake_case`, descriptive (e.g., `database_instance_class`)
- Locals: `snake_case` for computed values
- Data sources: prefix with purpose (e.g., `data.aws_ami.latest_ubuntu`)

## Security

- Scan with Trivy: `trivy config .`
- No hardcoded credentials in .tf files
- Use `sensitive = true` for secret variables
- Enable encryption at rest for all storage resources
- Restrict security group ingress to minimum required

## Forbidden

- `terraform destroy -auto-approve` (always require confirmation)
- `terraform apply -auto-approve` in production
- Hardcoded AMI IDs / resource IDs (use data sources)
- Committing .tfstate or .tfvars with secrets
