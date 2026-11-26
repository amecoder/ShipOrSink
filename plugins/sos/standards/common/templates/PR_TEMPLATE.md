# Pull Request 템플릿

> 이 템플릿을 `.github/PULL_REQUEST_TEMPLATE.md`에 복사하여 사용한다.

---

## 요약
<!-- 변경 사항을 1-3줄로 요약 -->


## 연결 문서

- PRD: <!-- docs/product/... 또는 N/A -->
- Feature Spec: <!-- docs/specs/... 또는 N/A -->
- AI Task Spec: <!-- docs/AI_TASK_SPEC.md 또는 N/A -->
- ADR/Design Doc: <!-- docs/adr/... 또는 docs/design-docs/... 또는 N/A -->
- Refactoring Plan: <!-- docs/REFACTORING_PLAN.md 또는 N/A -->

## 변경 유형

- [ ] 기능 (Feature)
- [ ] 버그 수정 (Bug Fix)
- [ ] 성능 개선 (Performance)
- [ ] 리팩터링 (Refactoring)
- [ ] 문서 (Documentation)
- [ ] 빌드/CI (Build/CI)
- [ ] 기타: ___

## 변경 내용
<!-- 주요 변경을 bullet point로 작성 -->
-

## 테스트

- [ ] TDD 순서 준수 (RED → GREEN → REFACTOR) 또는 예외 사유 기록
- [ ] 단위 테스트 추가/수정
- [ ] 통합 테스트 추가/수정
- [ ] 수동 테스트 완료

### 테스트 방법
<!-- 리뷰어가 검증할 수 있도록 테스트 절차와 결과를 기술 -->
```bash
# 테스트 실행 커맨드
```
<!-- 커버리지: __% -->

## 자동 검증 (CI 가 판정 — 체크하지 않는다)

<!-- ruleset 이 적용된 저장소(public 또는 Pro 이상 private)에서는 아래 체크가 실패하면 머지가 막힌다.
     Free 플랜 private 저장소는 ruleset 을 만들 수 없어 빨간불이 "안내"에 그친다 — 그래도 빨간불이면 머지하지 않는 것이 규칙이다. -->

| 체크 | 무엇을 보는가 | 실패하면 |
|---|---|---|
| `pr-policy` | `Closes #N` · 변경 ≤ 800줄(lockfile 제외) · 위 '테스트 방법'과 아래 '롤백 계획' 작성 여부 | 라벨 `no-issue` / `large-pr-approved` 로 예외, 섹션은 채워야 통과 |
| `security-review` | Semgrep(SAST) · Gitleaks(시크릿) · Trivy(의존성·IaC) | 수정하거나, 사람이 사유를 적고 수용 |
| 언어 CI (`lint` · `typecheck` · `test`) | 포맷 · 타입 · 테스트 · 커버리지 ≥ 80% | ruleset 의 필수 체크에 등록된 job 은 통과 전 머지 불가 |
| 로컬 훅 영수증 | push 직전, 테스트가 통과한 트리와 push 되는 커밋의 트리가 같은지 | `git push` / `gh pr create` 자체가 차단 (로컬 가드레일 — 최종 판정은 CI) |

<!-- `.github/` 의 워크플로우·스크립트를 바꾸는 PR 은 그 PR 버전으로 체크가 돌아간다. 체크가 초록이어도 리뷰어가 스크립트 diff 를 먼저 본다. -->

## 운영 안전성

### 위험도
- [ ] Low — 기존 동작에 영향 없음
- [ ] Medium — 일부 기능에 영향, 롤백 가능
- [ ] High — 핵심 기능 변경, 데이터 마이그레이션 포함

### 배포 계획
<!-- 해당하는 항목만 체크 -->
- [ ] Feature Flag 사용: `FEATURE_NAME=false`
- [ ] 데이터 마이그레이션 필요 (스크립트 위치: ___)
- [ ] 환경 변수 추가/변경 필요 (변수명: ___)
- [ ] 모니터링/알림 설정 변경

### 롤백 계획
<!-- 이 변경이 실패하면 어떻게 복구하는가? -->
- 롤백 방법:
- 영향 범위:

## 체크리스트 — 사람이 판단하는 것만 (기계가 보는 항목은 위 표)

### 설계 · 코드 품질
- [ ] 함수 ≤50줄, 파일 ≤800줄, 복잡도 ≤15 — 린터가 못 잡는 경계는 리뷰어가 본다
- [ ] 리팩터링은 동작 변경과 분리했거나, 분리하지 못한 이유를 설명함
- [ ] 공개 API/이벤트/DB 계약 변경 시 호환성 체크리스트 작성
- [ ] 범위가 이슈(AI Task)에 적힌 것과 같다 — 몰래 넓히지 않았다
- [ ] `.github/` · `.claude/` 를 바꿨다면 체크 결과보다 스크립트 diff 를 먼저 읽었다 (체크는 PR 버전으로 돈다)

### 보안 — 자동 스캔이 못 보는 것
- [ ] 사용자 입력 검증이 시스템 경계에서 이루어짐
- [ ] SQL 인젝션 / XSS / CSRF 방지 확인 (Semgrep 은 일부만 잡는다)
- [ ] 인증/인가 검증 완료 (해당 시) — 라벨 `security` 붙이고 security-engineer 리뷰
- [ ] 에러 메시지에 민감 정보 노출 없음

### 문서
- [ ] 공개 API 변경 시 문서 업데이트
- [ ] 필요 시 CHANGELOG.md 갱신
- [ ] 아키텍처 변경 시 ADR 작성

### 기타
- [ ] 셀프 리뷰 완료
- [ ] 불필요한 console.log / print / 디버그 UI 제거
- [ ] 하위 호환성 확인 (Breaking Change 없음 또는 명시)

## 관련 이슈
<!-- Closes #이슈번호 -->

## 스크린샷 (UI 변경 시)
<!-- Before / After 스크린샷 -->

| Before | After |
|--------|-------|
|        |       |

## 리뷰어 참고 사항
<!-- 리뷰 시 특히 봐야 할 부분, 우려 사항 등 -->
