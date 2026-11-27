#!/usr/bin/env bash
# ============================================================================
# apply-github-settings.sh — git 에 있는 정의 파일을 GitHub 저장소 설정에 반영 (멱등)
# ============================================================================
# 무엇을 하나:
#   1. .github/labels.json      → gh label create --force  (있으면 색·설명 갱신)
#   2. .github/rulesets/*.json  → gh api repos/{owner}/{repo}/rulesets (같은 이름이 있으면 PUT, 없으면 POST)
#
# 브랜치 보호를 "웹 UI 에서 클릭"이 아니라 코드로 관리한다. 설정을 바꾸려면 JSON 을 고치고 다시 실행한다.
#
# 사용법:
#   bash .github/scripts/apply-github-settings.sh                 # 현재 저장소 (gh repo view 로 감지)
#   bash .github/scripts/apply-github-settings.sh --repo o/r      # 다른 저장소
#   bash .github/scripts/apply-github-settings.sh --dry-run       # API 호출 없이 계획만 출력
#   bash .github/scripts/apply-github-settings.sh --only labels   # labels | rulesets
#
# 필수 조건:
#   - gh 로그인 (gh auth status) · jq
#   - ruleset 은 public 저장소 또는 GitHub Pro/Team/Enterprise 의 private 저장소에서만 동작한다.
#     Free 플랜 private 저장소는 API 가 403 을 돌려준다 → 이 스크립트가 원인을 출력하고 exit 1.
#     그 경우 pr-policy · security-review 는 "빨간불 안내"일 뿐 머지를 막지 못한다 (레거시 branch protection 도 동일하게 403).
#   - 언어별 CI job (lint · typecheck · test) 을 필수 체크에 넣으려면 rulesets/main-protection.json 의
#     required_status_checks 에 {"context": "<job name>"} 을 추가한다. context 는 워크플로우 job 의 `name:` 값이다.
# ============================================================================
set -euo pipefail

GITHUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABELS_FILE="$GITHUB_DIR/labels.json"
RULESETS_DIR="$GITHUB_DIR/rulesets"
REPO=""
DRY_RUN=false
ONLY=""

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)    REPO="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --only)    ONLY="$2"; shift 2 ;;
        --help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) error "알 수 없는 옵션: $1"; exit 1 ;;
    esac
done

command -v gh >/dev/null 2>&1 || { error "gh 가 필요합니다 — scripts/install-dev-tools.sh"; exit 1; }
command -v jq >/dev/null 2>&1 || { error "jq 가 필요합니다 — scripts/install-dev-tools.sh"; exit 1; }

if [[ -z "$REPO" ]]; then
    REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
    [[ -n "$REPO" ]] || { error "저장소를 감지하지 못했습니다 — --repo owner/name 을 지정하세요"; exit 1; }
fi
info "대상 저장소: $REPO $([[ "$DRY_RUN" == true ]] && echo '(dry-run)')"

# ─── 라벨 ───────────────────────────────────────────────────────────────
apply_labels() {
    [[ -f "$LABELS_FILE" ]] || { warn "labels.json 없음 — 건너뜀"; return 0; }
    local count=0 name color desc
    # NUL 구분 — 설명에 탭·백슬래시·따옴표가 있어도 그대로 전달된다
    while IFS= read -r -d '' name && IFS= read -r -d '' color && IFS= read -r -d '' desc; do
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] label: $name (#$color) — $desc"
        else
            gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force >/dev/null
        fi
        count=$((count + 1))
    done < <(jq -j '.[] | (.name, "\u0000", .color, "\u0000", .description, "\u0000")' "$LABELS_FILE")
    success "라벨 ${count}개 반영"
}

# ─── Ruleset ────────────────────────────────────────────────────────────
RULESET_FAILED=false

apply_rulesets() {
    [[ -d "$RULESETS_DIR" ]] || { warn "rulesets/ 없음 — 건너뜀"; return 0; }
    local file name existing_id list_err
    for file in "$RULESETS_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        name="$(jq -r .name "$file")"
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] ruleset: $name ← $(basename "$file")"
            continue
        fi
        # 플랜 제한(403)은 여기서 드러난다 — 라벨은 이미 반영됐으므로 원인만 분명히 알린다
        # includes_parents=false: 같은 이름의 org 룰셋 id 로 PUT 하는 사고 방지
        if ! list_err="$(gh api "repos/$REPO/rulesets?includes_parents=false&per_page=100" 2>&1 >/dev/null)"; then
            if [[ "$list_err" == *"Upgrade to GitHub Pro"* || "$list_err" == *"403"* ]]; then
                error "ruleset 을 만들 수 없습니다 — $REPO 는 Free 플랜의 private 저장소입니다 (HTTP 403)"
                error "  → public 으로 전환하거나 GitHub Pro 이상으로 올려야 브랜치 보호가 적용됩니다"
                error "  → 그때까지 pr-policy · security-review 는 CI 안내일 뿐 머지를 막지 못합니다"
            else
                error "ruleset 목록 조회 실패: $list_err"
            fi
            RULESET_FAILED=true
            return 0
        fi
        existing_id="$(gh api "repos/$REPO/rulesets?includes_parents=false&per_page=100" \
            --jq --arg n "$name" 'first(.[] | select(.name == $n and .source_type == "Repository")).id // empty' 2>/dev/null || true)"
        if [[ -n "$existing_id" ]]; then
            gh api --method PUT "repos/$REPO/rulesets/$existing_id" --input "$file" >/dev/null
            success "ruleset 갱신: $name (id $existing_id)"
        else
            gh api --method POST "repos/$REPO/rulesets" --input "$file" >/dev/null
            success "ruleset 생성: $name"
        fi
    done
}

case "$ONLY" in
    "")        apply_labels; apply_rulesets ;;
    labels)    apply_labels ;;
    rulesets)  apply_rulesets ;;
    *) error "알 수 없는 --only 값: $ONLY (labels | rulesets)"; exit 1 ;;
esac

[[ "$DRY_RUN" == true ]] || info "확인: gh label list --repo $REPO · gh api repos/$REPO/rulesets --jq '.[].name'"
[[ "$RULESET_FAILED" == true ]] && exit 1
exit 0
