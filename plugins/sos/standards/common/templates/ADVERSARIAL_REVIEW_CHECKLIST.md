# Adversarial Review Checklist

Use this checklist after implementation but before handoff for meaningful changes.

## Four-Eyes Principle (필수 — AI 에이전트 작성 코드)

작성한 에이전트가 자기 코드를 같은 세션에서 리뷰하면 편향이 발생한다. 반드시 다음을 보장:

- [ ] **모델 분리**: 작성과 리뷰는 서로 다른 모델 (예: Claude가 작성 → Codex가 리뷰)
- [ ] **세션 분리**: 리뷰 에이전트는 fresh context (작성 세션의 메시지/도구결과 미공유)
- [ ] **입력 최소화**: 리뷰는 (1) 변경된 diff (2) 원래 요구사항 만 받음 — 작성 과정의 reasoning은 노출 X
- [ ] **독립 결정**: 리뷰가 "무엇이 옳은가"를 작성과 무관하게 판단 (작성 결과를 따라가지 않음)
- [ ] **합의 불일치**: 작성과 리뷰가 충돌하면 인간 또는 3차 에이전트에 에스컬레이트, 임의 채택 금지

라우팅 예시:
- A 제공사 모델 작성 → B 제공사 모델 리뷰 (예: Anthropic Claude 작성 → OpenAI Codex 리뷰, 그 반대도)
- 같은 제공사뿐이면 → 다른 등급·다른 세션으로 리뷰
- 단일 모델 사용 시 → 별도 시스템 프롬프트 + 새 세션


## Requirements

- [ ] Does the implementation actually satisfy the PRD/Spec/Task Spec?
- [ ] Are out-of-scope items still out of scope?
- [ ] Are acceptance criteria observable and verified?

## Correctness

- [ ] Are edge cases covered?
- [ ] Are failures handled at I/O and user-facing boundaries?
- [ ] Are race conditions, retries, idempotency, and ordering handled when relevant?
- [ ] Are migrations reversible or safely forward-only?

## Security and Privacy

- [ ] Are inputs validated?
- [ ] Are authn/authz boundaries preserved?
- [ ] Are secrets excluded from code, docs, logs, and agent context?
- [ ] Are PII classification, retention, deletion, and audit requirements met?

## AI Behavior

- [ ] Are prompts versioned or documented?
- [ ] Are outputs schema-validated?
- [ ] Are fallback and refusal paths covered?
- [ ] Did eval quality, latency, and cost stay within threshold?

## Maintainability

- [ ] Is the change smaller than the problem requires?
- [ ] Are names, module boundaries, and dependencies consistent with the repo?
- [ ] Is duplication intentional or removed?
- [ ] Is technical debt recorded if accepted?

## Handoff

- [ ] `HANDOFF.md` updated.
- [ ] `CHANGELOG.md` updated for user-visible changes.
- [ ] Skipped checks documented with exact reason.
