# CHANGELOG

이 저장소의 변경 기록이다. 머지할 때마다 위에 한 줄씩 더한다.

## 2026-11-27

- **#1** `2502d42` 문서: sos 표준 설치 안내와 설명서 정리 (단독 운영 1/4)
  - 비공개 원래 저장소 clone 안내 92줄을 `$SOS_STANDARDS` 기준으로 교체, `plugins/sos/standards/README.md` 설명서 추가
  - 주석·배너·도움말 이름표를 sos 로 교체 (`.dev-standards.manifest`·`dev-standards:issue-gate` 표식은 호환을 위해 유지)
  - 복사 흔적 `.source-commit`·`.local-changes` 삭제
  - 후속: `apply.sh --help` 색 코드가 글자로 찍히는 기존 문제는 PR 2 에서 고친다. 플러그인 버전은 0.1.0 그대로(PR 4)
- `9c87f98` 기능: ShipOrSink(sos) 단계 플러그인 첫 공개
