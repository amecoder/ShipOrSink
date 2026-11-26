# Meetings - 회의록 관리 가이드

> 이 디렉토리는 AI 자동화 + 사람 보정 워크플로우로 회의록을 관리한다.

## 디렉토리 구조

```
meetings/
  README.md              # 이 파일 (가이드)
  glossary.md            # 용어집 — STT 오류 보정 + 사내 용어 정의
  templates/             # 회의 유형별 템플릿
    weekly.md
    retrospective.md
    decision.md
    adhoc.md
  YYYY/MM/               # 보정 완료된 회의록 (연/월 기준)
    YYYY-MM-DD_제목.md
```

## 워크플로우

```
[녹취록 입력] (Linear Todo + ai:meetings)
       │
       ▼
  AI 처리 (correct → minutes)
  ├── glossary.md로 용어 보정
  └── templates/ + 최근 회의록으로 맥락 참조
       │
       ▼
  프로젝트 레포에 PR 생성 (meetings/YYYY/MM/YYYY-MM-DD_제목.md)
  Linear → In Review
       │
       ▼
  사람이 PR에서 보정
  ├── 용어/맥락/누락 보완
  └── glossary.md 업데이트 (새 용어 발견 시)
       │
       ▼
  Merge → 보정 완료본이 레포에 저장
  Linear → Done
       │
       ▼
  다음 회의 시 AI가 meetings/ 참조 (컨텍스트 누적)
```

## 규칙

### 파일 명명
- 형식: `YYYY-MM-DD_회의-제목.md`
- 예시: `2026-04-14_주간회의.md`, `2026-04-10_인증-설계-검토.md`

### 프론트매터 (필수)
모든 회의록에 아래 프론트매터를 포함한다:

```yaml
---
type: weekly | retrospective | decision | adhoc
date: YYYY-MM-DD
participants: [이름1, 이름2]
duration: 30min
tags: [프로젝트명, 주제]
status: draft | reviewed
---
```

- `draft`: AI가 생성한 초안 (PR 생성 시점)
- `reviewed`: 사람이 보정 완료 (PR merge 시점)

### 용어집 관리
- 새로운 STT 오류나 사내 용어를 발견하면 `glossary.md`에 추가
- 회의록 PR에 glossary 업데이트를 함께 포함
- AI는 correct phase에서 glossary.md를 참조하여 자동 보정

### 컨텍스트 참조
- AI는 minutes phase에서 최근 2~3개 회의록을 프롬프트에 포함
- 이전 회의의 결정사항, 액션아이템 follow-up을 자연스럽게 연결
- `reviewed` 상태의 회의록만 컨텍스트로 사용

## 체크리스트

### AI 초안 생성 시
- [ ] glossary.md 참조하여 용어 보정
- [ ] 템플릿 구조를 따라 작성
- [ ] 최근 회의록 컨텍스트 반영
- [ ] 프론트매터 `status: draft`

### 사람 보정 시
- [ ] 용어/이름 오류 수정
- [ ] 맥락이 빠진 부분 보완
- [ ] 액션 아이템 담당자/기한 확인
- [ ] 새 용어 발견 시 glossary.md 업데이트
- [ ] 프론트매터 `status: reviewed`로 변경 (merge 시 자동)
