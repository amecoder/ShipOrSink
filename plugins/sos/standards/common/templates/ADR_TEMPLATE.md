# ADR 템플릿

> Architecture Decision Record — 아키텍처 결정을 기록하고 추적하는 문서.
> 파일명: `docs/adr/NNNN-제목.md` (번호 순차 증가)
> Michael Nygard 형식 기반.

---

## 사용법

1. `docs/adr/` 디렉토리에 새 파일 생성
2. 번호를 순차 증가시켜 파일명 지정
3. 아래 템플릿을 복사하여 작성
4. 코드와 함께 Git에 커밋

### 운영 규칙

- `## Enforced by` 에는 결정을 지키는 테스트·CI 잡 이름, 또는 `advisory: <사유>` 를 적는다 (MADR 4 의 Confirmation 과 같은 취지)
- 한 번 **Accepted**된 ADR은 수정하지 않는다
- 결정을 변경하려면 새 ADR을 작성하고 기존 ADR을 **Superseded** 상태로 변경
- 주요 기술 선택, 아키텍처 변경, 표준 도입 시 반드시 작성
- PR에 ADR을 포함하여 코드와 결정의 이력을 동기화

---

## 템플릿

```markdown
# ADR-NNNN: 제목

## Status

Proposed | Accepted | Rejected | Deprecated | Superseded by [ADR-XXXX]

## Date

YYYY-MM-DD

## Participants

- (결정에 참여한 사람 목록)

## Context

이 결정이 필요한 배경을 설명한다.
- 기술적/비즈니스적 컨텍스트
- 제약 조건
- 고려한 대안과 그 장단점

## Decision

우리는 [결정 사항]을 선택한다.

결정의 구체적인 내용과 이유를 기술한다.

## Consequences

### 긍정적
- 장점 1
- 장점 2

### 부정적
- 단점 1 (및 완화 방안)

### 중립적
- 추가 작업 필요 사항

## Enforced by

이 결정을 기계가 지키는 장치를 적는다. 없으면 없다고 적는다 — 체크박스나 "준수한다"는 문장은 장치가 아니다.

- 테스트 · CI 잡 이름: (예: `tests/architecture/ModuleBoundaryTest` · CI 잡 `arch-fitness`)
- 또는 `advisory: <사유>` — 리뷰로만 지킨다 (예: "런타임 설정이라 정적 검사 불가 — 코드 리뷰 체크리스트 항목")
```

---

## 예시

```markdown
# ADR-0001: 인증 방식으로 JWT 채택

## Status

Accepted

## Date

2026-03-11

## Context

- 마이크로서비스 아키텍처에서 서비스 간 인증 필요
- 세션 기반 인증은 수평 확장에 부적합
- 모바일/웹 클라이언트 동시 지원 필요

### 고려한 대안

| 방식 | 장점 | 단점 |
|------|------|------|
| Session | 구현 간단, 즉시 폐기 가능 | 수평 확장 어려움, sticky session 필요 |
| JWT | Stateless, 수평 확장 용이 | 즉시 폐기 불가 |
| OAuth2 + Opaque Token | 보안성 높음 | 복잡도 높음, 토큰 검증 시 auth 서버 호출 필요 |

## Decision

JWT (JSON Web Token) 기반 인증을 채택한다.
- Access Token: 15분 만료, RS256 알고리즘
- Refresh Token: 7일 만료, Redis 저장
- Token Rotation: refresh 시 기존 토큰 블랙리스트에 추가

## Consequences

### 긍정적
- Stateless: 수평 확장 용이
- 클라이언트 종류 무관하게 동일 인증 흐름
- 서비스 간 인증에 별도 세션 스토어 불필요

### 부정적
- 토큰 즉시 폐기 불가 → 완화: 짧은 Access Token 만료(15분) + Refresh Token 블랙리스트
- 토큰 크기로 인한 네트워크 오버헤드 → 완화: 페이로드 최소화

### 중립적
- JWT 라이브러리 의존성 추가 (jjwt / PyJWT / jose)
- 키 관리 인프라 구축 필요 (RS256 키 페어 로테이션)

## Enforced by

- `AuthTokenTest`(Access Token 만료 15분 · RS256 서명 검증) — CI 잡 `test`
- advisory: Refresh Token 블랙리스트 적재는 Redis 운영 설정이라 리뷰 체크리스트로만 확인
```
