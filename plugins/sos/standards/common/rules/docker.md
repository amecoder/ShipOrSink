---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*.yml"
  - "**/docker-compose*.yaml"
  - "**/.dockerignore"
---

# Docker Rules

- Multi-stage builds for production images
- Pin base image versions: `python:3.12-slim` not `python:latest`
- Non-root USER: `RUN adduser --disabled-password app && USER app`
- Minimize layers: combine RUN commands with `&&`
- Copy dependency files first, then source (layer caching)
- Use .dockerignore to exclude .git, node_modules, __pycache__, .env
- No secrets in Dockerfile (use build args or runtime env)
- HEALTHCHECK instruction for production images
- LABEL for metadata (maintainer, version, description)

## Layer Ordering (cache optimization)

```
FROM base
COPY requirements.txt .     # 1. Dependencies (changes rarely)
RUN pip install -r ...       # 2. Install deps
COPY . .                     # 3. Source code (changes often)
```

## Security

- Scan with Trivy: `trivy image <name>`
- No sensitive data in ENV instructions
- Use COPY over ADD (explicit behavior)
- Pin package versions in RUN apt-get/apk

## Forbidden

- `latest` tag for base images
- Running as root in production
- Storing secrets in image layers
- `ADD` for remote URLs (use `curl` + `COPY`)
