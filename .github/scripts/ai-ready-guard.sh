#!/usr/bin/env bash
# ============================================================================
# ai-ready-guard.sh — "ai-ready 라벨은 사람만 붙인다" 를 판정 (ai-ready-guard.yml 이 호출)
# ============================================================================
# 규칙 문서(multi-agent-orchestration.md)만으로는 에이전트가 자기 이슈에 ai-ready 를 붙이는 것을 못 막는다.
# 이 스크립트는 라벨을 붙인 주체를 보고 allow / deny 를 결정한다. 워크플로우가 deny 면 라벨을 떼고 코멘트를 남긴다.
#
# 입력 (환경변수):
#   LABEL         붙은 라벨 이름 (ai-ready 가 아니면 항상 allow)
#   SENDER        라벨을 붙인 로그인 (예: alice · github-actions[bot] · claude[bot])
#   SENDER_TYPE   GitHub 계정 타입: User | Bot | Organization
#   PERMISSION    저장소 권한: admin | maintain | write | triage | read | none
#                 (gh api repos/{owner}/{repo}/collaborators/{SENDER}/permission --jq .permission)
#
# 출력: 표준출력에 "allow" 또는 "deny: <이유>", exit 0 / 1
# ============================================================================
set -euo pipefail

LABEL="${LABEL:-}"
SENDER="${SENDER:-}"
SENDER_TYPE="${SENDER_TYPE:-User}"
PERMISSION="${PERMISSION:-none}"
GUARDED_LABEL="${GUARDED_LABEL:-ai-ready}"

if [[ "$LABEL" != "$GUARDED_LABEL" ]]; then
    echo "allow"
    exit 0
fi

# 봇 계정: GitHub App 봇(login 이 [bot] 로 끝남) 또는 sender.type == Bot
if [[ "$SENDER_TYPE" == "Bot" || "$SENDER" == *"[bot]" ]]; then
    echo "deny: '$GUARDED_LABEL' 는 사람이 검토한 뒤 붙이는 라벨입니다 — 봇 계정($SENDER)이 붙였으므로 뗍니다"
    exit 1
fi

case "$PERMISSION" in
    admin|maintain|write)
        echo "allow"
        exit 0 ;;
    *)
        echo "deny: '$GUARDED_LABEL' 는 저장소 write 권한 이상만 붙일 수 있습니다 — $SENDER 의 권한: $PERMISSION"
        exit 1 ;;
esac
