# Git Workflow Rules

Git history must make review, rollback, and audit straightforward.

## Branching

- Never commit directly to `main` or `master`.
- Use short-lived feature branches: `feat/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`, `chore/*`.
- Rebase or merge from the base branch before requesting review when conflicts or drift are material.
- Do not rewrite shared branch history without explicit coordination.

## Commits

- Commit messages use `<type>: <title>`.
- Supported Korean types: `기능`, `수정`, `문서`, `스타일`, `리팩터`, `테스트`, `빌드`, `CI`.
- Keep commits reviewable and logically grouped.
- Do not mix unrelated refactors with behavior changes.

## Pull Requests

- Link the issue: `Closes #N` in the body. Issue-less PRs carry the `no-issue` label (typos, CI settings).
- Keep PRs under 800 changed lines (lockfiles excluded); split otherwise, or a reviewer adds `large-pr-approved` with a reason.
- Fill `### 테스트 방법` with the exact commands and results, and `### 롤백 계획` with how to undo. The `pr-policy` check fails on empty sections.
- Include user-visible behavior, risk, and screenshots for UI changes.
- Required checks (`pr-policy`, `security-review`, and the language CI jobs) must pass before merge.
- Use squash merge for feature branches unless the project has a different documented policy.
- Do not `git push` or `gh pr create` until the test suite passed on the exact tree being pushed; the pre-tool-use guard checks the test receipt.

## Protection

- Branch protection lives in git as a ruleset (`.github/rulesets/main-protection.json`) and is applied with `.github/scripts/apply-github-settings.sh`. Change the JSON, re-run the script; do not click settings in the web UI.
- The ruleset blocks deletion and force pushes on `main`, requires a PR with one approval, CODEOWNERS review, resolved threads, and the required status checks.
- Rulesets exist only on public repositories or on private repositories under GitHub Pro/Team/Enterprise. On a Free-plan private repository the API returns 403: the CI checks still run and report, but nothing blocks the merge — treat a red check as a hard stop by convention until the plan or visibility changes.
- Two profiles: `main-protection.json` (team — one approval + CODEOWNERS, no bypass) and `main-protection-solo.json` (single owner — zero approvals, repository admins bypass only through a PR). A single-owner repository with the team profile can never merge, because nobody else can approve.
- Require signed commits or trusted CI provenance where the repository handles production or customer data.
