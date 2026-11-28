#!/usr/bin/env bats
# tests/release.bats — 플러그인 버전과 CHANGELOG 의 릴리스 절이 어긋나지 않게 한다 (CLAUDE.md 「릴리스」).
# Claude Code updates an installed plugin only when plugin.json's version changes, so every release
# needs a new version and a CHANGELOG section that says what that version contains.

load helpers

PLUGIN_JSON="$PROJECT_ROOT/plugins/sos/.claude-plugin/plugin.json"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

setup() {
    require_tool jq
}

plugin_version() {
    jq -r '.version' "$PLUGIN_JSON"
}

@test "release: plugin.json 버전은 정식판 X.Y.Z 다 (alpha·beta·RC 접미사 없음)" {
    local v
    v="$(plugin_version)"
    [[ "$v" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo "not a plain X.Y.Z release version: [$v]"; return 1; }
}

@test "release: CHANGELOG 에 지금 플러그인 버전의 절 '## <버전> (YYYY-MM-DD)' 이 있다" {
    local v
    v="$(plugin_version)"
    grep -qE "^## ${v//./\\.} \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$" "$CHANGELOG" \
        || { echo "CHANGELOG.md has no '## $v (YYYY-MM-DD)' section for plugin.json version $v"; return 1; }
}

@test "release: CHANGELOG 의 버전 절은 새 버전이 위에 오고 같은 버전이 두 번 나오지 않는다" {
    local versions sorted
    versions="$(grep -oE '^## [0-9]+\.[0-9]+\.[0-9]+ ' "$CHANGELOG" | awk '{print $2}')"
    [ -n "$versions" ] || { echo "CHANGELOG.md has no version sections"; return 1; }
    sorted="$(sort -t. -k1,1nr -k2,2nr -k3,3nr -u <<< "$versions")"
    [ "$versions" = "$sorted" ] || { echo "version sections out of order or duplicated:"; echo "$versions"; return 1; }
}

@test "release: CHANGELOG 맨 위 버전 절이 plugin.json 버전이다 (릴리스하지 않은 머지는 '## 다음 릴리스' 아래)" {
    local top
    top="$(grep -oE '^## [0-9]+\.[0-9]+\.[0-9]+ ' "$CHANGELOG" | head -1 | awk '{print $2}')"
    [ "$top" = "$(plugin_version)" ] || { echo "newest CHANGELOG section is [$top], plugin.json says [$(plugin_version)]"; return 1; }
}
