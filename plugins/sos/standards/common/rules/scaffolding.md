---
paths:
  - "package.json"
  - "pyproject.toml"
  - "**/*.toml"
  - "Makefile"
  - "**/Makefile"
  - ".nvmrc"
  - ".node-version"
  - ".python-version"
  - ".tool-versions"
  - "mise.toml"
  - ".mise.toml"
  - "**/scripts/**"
  - "**/bootstrap*"
  - "**/setup*"
  - ".env.example"
  - "**/*.gradle*"
  - "gradle.properties"
  - "**/Gemfile"
  - "**/Package.swift"
  - "**/pubspec.yaml"
  - "**/go.mod"
  - "**/Cargo.toml"
---

# Scaffolding Rules

Project scaffolding must be reproducible, minimal, and easy to verify.

## Baseline

- Start from the smallest scaffold that supports the requested product surface.
- Commit lockfiles and framework config files.
- Keep generated files separate from hand-written source when the framework allows it.
- Prefer official generators and documented migration commands over copied boilerplate.
- Record non-obvious scaffold decisions in `docs/adr/` or the project handoff.

## Runtime And Tooling

- Declare runtime versions in the repo (`.nvmrc`, `.node-version`, `.python-version`, `mise.toml`, `gradle.properties`, or equivalent).
- Prefer one package manager per project and enforce it with `packageManager` or documented setup.
- Keep scripts predictable: `lint`, `typecheck`, `test`, `test:coverage`, `build`, and `format:check`.
- Do not add global tool requirements when a local dev dependency or wrapper is practical.

## Configuration

- Use checked-in example files for required environment variables (`.env.example`).
- Never commit real `.env`, private keys, certificates, or cloud credentials.
- Keep config names aligned with the framework defaults unless there is a documented reason.
- Avoid scaffolding optional services until a feature needs them.

## Verification

- A fresh clone must be able to install, lint, test, and build from documented commands.
- Scaffolding changes must include a dry-run or bootstrap verification when the repository provides one.
- Template scripts must be idempotent: never overwrite existing project files without a prompt or explicit flag.
