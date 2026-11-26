---
paths:
  - "meetings/**/*.md"
description: 회의록 작성 및 보정 규칙
alwaysApply: false
---

# 회의록 규칙

## 프론트매터 (필수)
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

## 작성 규칙
- `meetings/templates/`의 해당 유형 템플릿 구조를 따른다
- `meetings/glossary.md`를 참조하여 용어를 보정한다
- 최근 2~3개 `reviewed` 상태 회의록을 컨텍스트로 활용한다
- 이전 회의 액션 아이템 follow-up을 자연스럽게 연결한다

## 용어 보정
- glossary.md의 용어 테이블을 기준으로 STT 오류를 교정한다
- 새로운 오류 패턴을 발견하면 glossary.md에 추가한다
- 인물명은 glossary.md의 인물 테이블과 대조한다

## 파일 명명
- 형식: `YYYY-MM-DD_회의-제목.md`
- 경로: `meetings/YYYY/MM/`

## 품질 기준
- 요약 섹션은 3줄 이내
- 모든 결정 사항에 근거를 포함한다
- 액션 아이템에 담당자와 기한을 명시한다
- 모호한 표현 ("나중에", "검토 예정") 대신 구체적 일시를 기재한다
