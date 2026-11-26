# AGENTS.md

## Language

- Conversations, commits, and docs: Korean.
- Code comments: English unless the project already uses another convention.

## Core Workflow

- Verify before acting.
- Read relevant files before editing.
- Keep changes scoped to the task.
- Update `HANDOFF.md`, `CHANGELOG.md`, `TODO.md`, or `.codex/progress.md` when project state changes.
- Do not leave TODO placeholders for requested work unless the user explicitly defers the scope.

## Workflow Skills (요약 — 전문은 `.claude/skills/<name>/SKILL.md`, 필요할 때 `/<name>` 으로 로드)

- **Refactoring** (`/refactoring`): 동작을 바꾸지 않는 구조 변경. 먼저 characterizing test, 범위는 리뷰 가능한 크기, 기능 변경과 같은 PR 에 섞지 않는다. 새 추상화·전면 재작성은 근거 없이 하지 않는다.
- **Vibe-to-Production** (`/vibe-to-production`): 프로토타입은 자유, 프로덕션은 스펙·테스트·리뷰·관측 가능한 수용 기준이 있어야 한다. 채팅에만 있는 기대 동작으로는 배포하지 않는다.
- **AI Review Loop** (`/ai-review-loop`): 공개 API·스키마·인증·과금·프롬프트·다중 서브시스템 변경은 독립 리뷰가 필수. 구현자가 의도·변경 파일·검증을 기록하고, 리뷰어는 저장소 사실을 확인한다. `[필수]` 지적은 수정 또는 사용자 승인 전 인계 금지.
- **AI Task Spec** (`/ai-task-spec`): 사소하지 않은 작업은 목표·범위·비범위·수용 기준을 먼저 적는다(이슈 `AI Task` 폼과 같은 형태). 모호한 요청을 범위를 넓혀 조용히 구현하지 않는다.
- **Plan Mode** (`/plan-mode-workflow`): 아키텍처·데이터·보안·과금·여러 서브시스템을 건드리면 편집 전에 계획을 세운다 (목표·비목표·저장소 사실·대안·파일 소유·TDD·검증·롤백). 계획이 구현으로 새지 않게 한다.

## Engineering Standards

- Use TDD for behavior changes: RED, GREEN, REFACTOR.
- Prefer immutable data updates.
- Keep functions small and nesting shallow.
- Validate user input at boundaries.
- Do not hardcode secrets.
- Run relevant tests, lint, typecheck, or build before handoff.

## Collaboration

<!-- dev-standards:issue-gate:start -->
- Autonomous runs (issue→PR pipelines, unattended agents) take work only from GitHub issues (`AI Task` form) labeled `ai-ready` (a human adds it), set `ai-in-progress`, and link the PR with `Closes #N`. Interactive requests from a human in the session may start directly.
<!-- dev-standards:issue-gate:end -->
- Claude Code and Codex should both follow this file plus any deeper `AGENTS.md`.
- Claude-specific behavior may live in `CLAUDE.md`; general project rules should stay here.
- When multiple agents work in parallel, do not revert changes made by others.
- Record ownership, changed files, verification commands, blockers, and next actions in handoff notes.

## Review Format

When reviewing, lead with findings ordered by severity. Label every finding with exactly one of:

- `[필수]` — must be fixed before merge
- `[제안]` — recommended improvement
- `[Nit]` — minor, non-blocking
- `[질문]` — needs clarification

End with a short summary (overall verdict, count of `[필수]`, notes). Approve only when there are zero `[필수]` findings.
