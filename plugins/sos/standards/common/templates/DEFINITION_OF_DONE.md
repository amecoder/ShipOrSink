# Definition of Done

Use this before handing work to a reviewer, another agent, or the user.

**Done is judged by evidence, not by checkboxes.** A checkbox is something the author can tick; it proves nothing. Every row below names the evidence and who judges it. Anything a machine can verify is verified by a machine.

## Required — judged by machines (no checkboxes)

| 항목 | 증거 | 판정자 |
|---|---|---|
| Lint · format · type · build pass | CI jobs `lint` / `typecheck` / `build` succeed | CI — blocks the merge only after you add these job names to the ruleset (see below) |
| Tests for changed behavior pass | CI job `test` succeeds, and the local receipt (`.git/claude/receipts.json`) contains the tree of the commit being pushed | CI + `pre-tool-use-guard` (blocks `git push` / `gh pr create` otherwise) |
| Coverage ≥ 80% on changed code | `test` job threshold step (`--cov-fail-under=80`, `COVERAGE_THRESHOLD`) | CI — blocks the merge only after you add the `test` job to the ruleset (see below) |
| No secrets, no known CRITICAL/HIGH vulnerabilities, no SAST findings | `security-review` (Semgrep + Gitleaks + Trivy) succeeds; pre-commit gitleaks/detect-secrets pass locally | GitHub required status check |
| Issue linked, PR ≤ 800 lines, test method and rollback plan written | `pr-policy` succeeds | GitHub required status check |
| `.env`, keys, credentials untouched | `pre-tool-use-guard` blocks the edit; gitleaks scans history | Hook + CI |

**What actually blocks a merge**: the shipped rulesets (`.github/rulesets/main-protection*.json`) require only `pr-policy` and `security-review`, because language CI job names differ per project. Until you add your `lint` / `typecheck` / `build` / `test` job names to `required_status_checks` there and re-run `apply-github-settings.sh`, a failing language CI job shows red but does **not** block the merge. Rulesets need a public repository or a paid plan (GitHub Free + private → 403).

If a row cannot be satisfied yet (no test suite, CI not wired), write the exact reason under `### 테스트 방법` in the PR and in `HANDOFF.md`. A human decides whether to accept it; the agent does not.

## Required — judged by a human reviewer

- [ ] Scope matches the approved PRD / Feature Spec / AI Task issue; nothing was added silently.
- [ ] TDD flow was followed where behavior changed (RED → GREEN → REFACTOR), or the exception is documented.
- [ ] Refactoring is separate from behavior changes, or the reason is documented.
- [ ] Privacy and retention impact considered (PII classification, data retention policy).
- [ ] User-facing docs or CHANGELOG updated when behavior changed.
- [ ] `HANDOFF.md`, `TODO/TODOS.md`, or `.codex/progress.md` updated when state changed.
- [ ] Skipped checks are documented with a concrete reason and an owner.

## UI Changes (reviewer confirms with screenshots)

- [ ] Desktop state checked.
- [ ] Mobile state checked.
- [ ] Empty, loading, error, and success states checked when applicable.
- [ ] Text does not overflow or overlap.

## Data/API Changes

- [ ] Migration or schema change is documented with a rollback or forward-fix path.
- [ ] OpenAPI, AsyncAPI, Proto, or event contracts were updated when applicable.
- [ ] Backward compatibility considered; breaking changes are planned and announced.
- [ ] Authorization and validation are tested (evidence: test names in the PR).
- [ ] Error responses do not leak internals.

## AI/LLM Changes

- [ ] Prompt or parser changes have regression coverage (golden set re-run, per-failure-type pass rate reported).
- [ ] Fallback behavior is defined.
- [ ] Output is validated before use.
- [ ] Cost, latency, and privacy implications are recorded when relevant.
