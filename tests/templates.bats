#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# 템플릿 일관성 — 규칙 프론트매터 정책 · dogfooding 복사본 드리프트 · JSON 유효성

load 'helpers'

RULES="$REPO_ROOT/common/rules"
GH_TPL="$REPO_ROOT/common/github-templates"

# 세션 시작 시 항상 로드되는 9개 — paths: 프론트매터가 없어야 한다
ALWAYS_ON="security coding-convention git-workflow tdd definition-of-done project-memory \
           context-engineering agent-tooling multi-agent-orchestration"

@test "rules: paths: \"**/*\" 로 모든 파일에 걸린 규칙이 0개" {
    run grep -l -E '^\s*-\s*"\*\*/\*"\s*$' "$RULES"/*.md
    [ "$status" -ne 0 ]
}

@test "skills: 워크플로우 규칙 5개가 스킬로 존재하고 rules/ 에는 없다" {
    for s in refactoring vibe-to-production ai-review-loop ai-task-spec plan-mode-workflow; do
        [ -f "$REPO_ROOT/common/skills/$s/SKILL.md" ] || { echo "missing skill: $s"; return 1; }
        head -1 "$REPO_ROOT/common/skills/$s/SKILL.md" | grep -q '^---$'
        grep -q "^name: $s$" "$REPO_ROOT/common/skills/$s/SKILL.md"
        grep -q '^description: ' "$REPO_ROOT/common/skills/$s/SKILL.md"
        [ ! -f "$RULES/$s.md" ] || { echo "still a rule: $s"; return 1; }
        grep -q "/$s" "$REPO_ROOT/common/templates/AGENTS_TEMPLATE.md" || { echo "AGENTS summary missing: $s"; return 1; }
    done
}

@test "rules: 상시 로드 9개는 paths: 프론트매터가 없다" {
    for r in $ALWAYS_ON; do
        [ -f "$RULES/$r.md" ] || { echo "missing rule: $r"; return 1; }
        ! grep -q '^paths:' "$RULES/$r.md" || { echo "has paths: $r"; return 1; }
    done
}

@test "rules: 상시 로드 9개를 제외한 모든 규칙은 paths: 프론트매터가 있다" {
    for f in "$RULES"/*.md; do
        name="$(basename "$f" .md)"
        [[ " $ALWAYS_ON " == *" $name "* ]] && continue
        grep -q '^paths:' "$f" || { echo "no paths: $name"; return 1; }
    done
}

@test "rules: oop.md · functional.md 가 있고 코드 확장자만 타겟팅한다" {
    for r in oop functional; do
        [ -f "$RULES/$r.md" ]
        grep -q '^paths:' "$RULES/$r.md"
        grep -qE '\*\*/\*\.\{.*py.*ts.*\}' "$RULES/$r.md"
    done
}

@test "rules: 상시 로드 9개 합계가 20KB · 350줄 이하 (컨텍스트 예산 — 실측 324줄, 이전 475줄)" {
    total_lines=0
    for r in $ALWAYS_ON; do
        total_lines=$(( total_lines + $(wc -l < "$RULES/$r.md") ))
    done
    echo "always-on lines: $total_lines"
    [ "$total_lines" -le 350 ]
    total=0
    for r in $ALWAYS_ON; do
        total=$(( total + $(wc -c < "$RULES/$r.md") ))
    done
    echo "always-on total bytes: $total"
    [ "$total" -le 20480 ]
}

@test "rules: multi-agent-orchestration 이 이슈 기반 조율을 규정한다" {
    grep -qi 'issue' "$RULES/multi-agent-orchestration.md"
    grep -q 'ai-ready' "$RULES/multi-agent-orchestration.md"
}

@test "github: labels.json 은 유효한 JSON 이고 필수 라벨을 포함" {
    jq -e 'type=="array"' "$GH_TPL/labels.json"
    for l in ai-task ai-ready ai-in-progress needs-human blocked no-issue large-pr-approved; do
        jq -e --arg n "$l" 'map(.name) | index($n)' "$GH_TPL/labels.json" >/dev/null || { echo "missing label: $l"; return 1; }
    done
    jq -e 'all(.[]; has("name") and has("color") and has("description"))' "$GH_TPL/labels.json"
}

@test "github: ruleset 은 유효한 JSON 이고 pr-policy · security-review 를 필수 체크로 요구" {
    jq -e '.target=="branch" and .enforcement=="active"' "$GH_TPL/rulesets/main-protection.json"
    jq -e '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | index("pr-policy") and index("security-review")' \
        "$GH_TPL/rulesets/main-protection.json"
    jq -e '[.rules[].type] | index("deletion") and index("non_fast_forward") and index("pull_request")' "$GH_TPL/rulesets/main-protection.json"
}

@test "github: ruleset 필수 체크는 GitHub Actions 앱(15368)이 올린 status 만 인정한다 (사칭 방지)" {
    for f in "$GH_TPL/rulesets/main-protection.json" "$GH_TPL/rulesets/main-protection-solo.json" "$PROJECT_ROOT/.github/rulesets/main-protection.json"; do
        jq -e '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[] | .integration_id] | length > 0 and all(. == 15368)' "$f" >/dev/null \
            || { echo "integration_id missing: $f"; return 1; }
    done
}

@test "ci-templates: 아카이브된 semgrep-action 을 쓰지 않는다 (고정 이미지로 직접 실행)" {
    run grep -l 'uses: semgrep/semgrep-action' "$REPO_ROOT"/common/ci-templates/*.yml
    [ "$status" -ne 0 ]
    # pinned by tag AND digest in an annotated variable — format, not a fixed version (Renovate bumps it)
    for f in ci-python ci-typescript ci-go; do
        grep -qF '"semgrep/semgrep:${SEMGREP_VERSION}"' "$REPO_ROOT/common/ci-templates/$f.yml" || { echo "image not taken from SEMGREP_VERSION: $f"; return 1; }
        yq -r '.["env"].SEMGREP_VERSION' "$REPO_ROOT/common/ci-templates/$f.yml" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+@sha256:[0-9a-f]{64}' \
            || { echo "SEMGREP_VERSION is not tag@sha256 digest: $f"; return 1; }
    done
}

@test "ci: python 잡이 고정 버전 ruff·mypy 로 표준 훅 Python(hooklib.py)을 검사한다 (2026-10-28 설계 ①)" {
    runs="$(yq '.jobs.python.steps[].run' "$PROJECT_ROOT/.github/workflows/ci.yml")"
    printf '%s\n' "$runs" | grep -Fq 'pip" install --quiet "ruff==${RUFF_VERSION}" "mypy==${MYPY_VERSION}"' || { echo "버전 고정 설치 없음"; return 1; }
    local v
    for v in RUFF_VERSION MYPY_VERSION; do
        V="$v" yq -r '.["env"][strenv(V)]' "$PROJECT_ROOT/.github/workflows/ci.yml" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+' || { echo "$v is not an exact x.y.z pin"; return 1; }
    done
    printf '%s\n' "$runs" | grep -Fxq 'targets=(plugins/sos/standards/common/hooks/hooklib.py)' ||
        { echo "대상 목록이 다름"; return 1; }
    # 주석이 아닌 줄에서 대상 전체("${targets[@]}")를 받고, 뒤에 || true 같은 것이 붙지 않는다(줄 끝 주석만 허용)
    for cmd in 'ruff check' 'ruff format --check' 'mypy --strict --python-version 3\.12'; do
        printf '%s\n' "$runs" | grep -Eq "^ *$cmd \"\\\$\\{targets\\[@\\]\\}\"[[:space:]]*(#.*)?\$" || { echo "실행 줄 없음: $cmd"; return 1; }
    done
}

@test "github: 1인 저장소용 ruleset 프로필은 승인 0 + admin PR bypass 이고 필수 체크는 팀용과 같다" {
    solo="$GH_TPL/rulesets/main-protection-solo.json"
    jq -e '.name=="main-protection-solo" and .bypass_actors[0].actor_type=="RepositoryRole" and .bypass_actors[0].bypass_mode=="pull_request"' "$solo"
    jq -e '.rules[] | select(.type=="pull_request") | .parameters.required_approving_review_count==0 and .parameters.require_code_owner_review==false' "$solo"
    [ "$(jq -c '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]' "$solo")" = \
      "$(jq -c '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]' "$GH_TPL/rulesets/main-protection.json")" ]
    # 팀용은 승인 1 + CODEOWNERS + bypass 없음 — 2인 이상 전제
    jq -e '.bypass_actors==[] and (.rules[] | select(.type=="pull_request") | .parameters.required_approving_review_count==1)' "$GH_TPL/rulesets/main-protection.json"
}

@test "settings: 팀 설정이 훅·설정 파일 편집을 deny 하고 가드가 Edit/Write 도 본다" {
    S="$REPO_ROOT/common/.claude-settings-team.json"
    for d in 'Edit(.claude/hooks/**)' 'Edit(.claude/settings.json)' 'Edit(.claude/settings.local.json)' 'Bash(rm -fr *)' 'Bash(git push * -f)'; do
        jq -e --arg d "$d" '.permissions.deny | index($d)' "$S" >/dev/null || { echo "missing deny: $d"; return 1; }
    done
    # Claude Code ignores Write(path) in file permission checks (Edit(path) covers all file-editing tools) and warns at startup
    jq -e '[.permissions.deny[] | select(startswith("Write("))] | length == 0' "$S" >/dev/null || { echo "Write(path) rule is ignored — use Edit(path)"; return 1; }
    jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash|Edit|Write")' "$S" >/dev/null
    jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command | contains("test-receipt.sh"))' "$S" >/dev/null
    [ "$(jq -r '.env.TEST_RECEIPT_REQUIRED' "$S")" = "1" ]
}

@test "github: 이슈 폼 4종이 있고 ai-task 폼은 ai-ready 를 자동 부착하지 않는다" {
    for f in ai-task bug-report feature-request config; do
        [ -f "$GH_TPL/ISSUE_TEMPLATE/$f.yml" ]
    done
    # 폼이 자동으로 붙이는 라벨(labels:)에 ai-ready 가 있으면 안 된다 — 본문 설명에서 언급하는 것은 허용
    run grep -E '^labels:.*ai-ready' "$GH_TPL/ISSUE_TEMPLATE/ai-task.yml"
    [ "$status" -ne 0 ]
    grep -q 'blank_issues_enabled: false' "$GH_TPL/ISSUE_TEMPLATE/config.yml"
}

@test "github: pr-checks.yml 의 job 이름과 security-review.yml 의 집계 job 이름이 ruleset 과 일치" {
    grep -qE '^\s+pr-policy:' "$GH_TPL/workflows/pr-checks.yml"
    grep -qE '^\s+security-review:' "$REPO_ROOT/common/security-templates/security-review.yml"
}

@test "github: 워크플로우의 40자 SHA 핀이 실제 커밋을 가리킨다 (gh 인증·네트워크 없으면 skip)" {
    gh auth status >/dev/null 2>&1 || skip "gh 미인증"
    cd "$REPO_ROOT"
    while read -r ref; do
        repo="${ref%%@*}"; owner_repo="$(cut -d/ -f1,2 <<< "$repo")"; sha="${ref##*@}"
        gh api "repos/$owner_repo/commits/$sha" --jq .sha >/dev/null 2>&1 || { echo "dangling pin: $ref"; return 1; }
    done < <(grep -rhoE 'uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}' common/ "$PROJECT_ROOT/.github/" | sed 's/^uses: //' | sort -u)
}

@test "dogfooding: 이 저장소의 .github 협업 파일이 템플릿 원본과 동일 (드리프트 없음 · .claude 는 이 저장소에 깔지 않는다)" {
    cmp "$GH_TPL/workflows/pr-checks.yml"                       "$PROJECT_ROOT/.github/workflows/pr-checks.yml"
    cmp "$REPO_ROOT/common/security-templates/security-review.yml" "$PROJECT_ROOT/.github/workflows/security-review.yml"
    cmp "$REPO_ROOT/common/templates/PR_TEMPLATE.md"            "$PROJECT_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
    cmp "$GH_TPL/labels.json"                                   "$PROJECT_ROOT/.github/labels.json"
    # ruleset 은 저장소별 CI job 을 추가하는 것이 정상 사용법 — 템플릿의 필수 체크를 모두 포함하는지(상위집합)만 본다
    # (이 저장소는 1인 저장소라 solo 프로필을 쓴다)
    tpl_checks="$(jq -c '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]' "$GH_TPL/rulesets/main-protection.json")"
    jq -e --argjson tpl "$tpl_checks" \
        '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] as $mine | all($tpl[]; . as $c | $mine | index($c))' \
        "$PROJECT_ROOT/.github/rulesets/main-protection.json"
    for f in ai-task bug-report feature-request config; do
        cmp "$GH_TPL/ISSUE_TEMPLATE/$f.yml" "$PROJECT_ROOT/.github/ISSUE_TEMPLATE/$f.yml"
    done
    for f in apply-github-settings pr-policy ai-ready-guard; do
        cmp "$GH_TPL/scripts/$f.sh" "$PROJECT_ROOT/.github/scripts/$f.sh"
    done
    cmp "$GH_TPL/workflows/ai-ready-guard.yml"                  "$PROJECT_ROOT/.github/workflows/ai-ready-guard.yml"
    cmp "$REPO_ROOT/common/security-templates/gitleaks.toml" "$PROJECT_ROOT/.gitleaks.toml"
}

@test "dogfooding: .gitignore 가 개인 설정(settings.local.json)을 무시한다 (영수증은 .git 안이라 불필요)" {
    grep -q '^\.claude/settings\.local\.json' "$PROJECT_ROOT/.gitignore"
    grep -q '^\.claude/settings\.local\.json' "$REPO_ROOT/common/gitignore-additions.txt"
}

@test "templates: DoD 가 증거·판정자 표를 갖고 자동 판정 항목에 체크박스를 쓰지 않는다" {
    grep -q '판정자' "$REPO_ROOT/common/templates/DEFINITION_OF_DONE.md"
    grep -q 'security-review' "$REPO_ROOT/common/templates/DEFINITION_OF_DONE.md"
    grep -q 'receipts.json' "$REPO_ROOT/common/templates/DEFINITION_OF_DONE.md"
}

# zizmor (default persona) flags a missing persist-credentials but not an explicit `true`, so guard the value itself.
# Missing key prints `null`. Do not use yq `//` here: it treats `false` like null and replaces it.
checkout_persist_values() {
    local f
    for f in "$@"; do
        yq -r '.jobs[]?.steps[]? | select((.uses // "") | test("^actions/checkout@")) | .with."persist-credentials" | tostring' "$f" \
            | sed "s|^|$f: |"
    done
}

@test "github: 워크플로 템플릿의 모든 actions/checkout 이 persist-credentials: false 다 (명시한 true 는 zizmor 가 못 잡는다)" {
    cd "$REPO_ROOT"
    local all bad
    all="$(checkout_persist_values common/ci-templates/*.yml common/security-templates/*.yml common/github-templates/workflows/*.yml)"
    [ "$(grep -c . <<< "$all")" -ge 28 ] || { echo "too few checkouts found: $all"; return 1; }
    bad="$(grep -v ': false$' <<< "$all" || true)"
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

# CI runs on pull requests only: PR CI already ran on the merge ref, so a main re-run after the squash merge adds
# nothing (origin: a private repo's Actions minutes, measured 2026-11-05 as 22 min per PR + 17 min again on main).
# workflow_dispatch runs it on main on demand.
@test "ci: 자체 CI 는 PR 에서만 자동으로 돈다 — 머지 뒤 main 재실행 없음, 필요하면 수동 실행 (Actions 무료 시간 절약)" {
    run bash -c "yq -o=json '.on' '$PROJECT_ROOT/.github/workflows/ci.yml' | jq -e 'keys == [\"pull_request\", \"workflow_dispatch\"]'"
    [ "$status" -eq 0 ] || { echo "ci.yml triggers: $(yq -o=json -I=0 '.on' "$PROJECT_ROOT/.github/workflows/ci.yml")"; return 1; }
}

# Agent Skills spec (agentskills.io/specification) — prints one line per violation in a skills dir.
#   name: string, 1-64 chars, [a-z0-9] and single hyphens, no leading/trailing hyphen, equals the parent directory
#   description: string, 1-1024 chars · compatibility (optional): string, 1-500 chars · frontmatter: valid YAML
#   between a first-line --- and a closing ---. Lengths are Unicode characters (Python), not bytes — locale-proof.
# Scope: common/skills (what apply.sh --only skills ships).
SKILL_CHECK_PY='
import json, re, sys
d, fm = sys.argv[1], json.load(sys.stdin)
def s(key): return fm.get(key)
name, desc = s("name"), s("description")
if not isinstance(name, str): print(f"{d}: name is not a string"); name = None
elif not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name) or len(name) > 64:
    print(f"{d}: name {name!r} breaks the 1-64 [a-z0-9] / single-hyphen rules")
if name is not None and name != d: print(f"{d}: name {name!r} does not match its directory")
if not isinstance(desc, str): print(f"{d}: description is not a string")
elif not 1 <= len(desc) <= 1024: print(f"{d}: description length {len(desc)} not in 1..1024")
if "compatibility" in fm:
    c = fm["compatibility"]
    if not isinstance(c, str) or not 1 <= len(c) <= 500: print(f"{d}: compatibility must be a 1..500 char string")
'
skill_violations() { # skills-dir
    local dir d f fm
    for dir in "$1"/*/; do
        d="$(basename "$dir")"
        f="$dir/SKILL.md"
        [ -f "$f" ] || { echo "$d: SKILL.md missing"; continue; }
        fm="$(awk 'NR == 1 { if ($0 != "---") exit 1; next } /^---$/ { closed = 1; exit } { print }
                   END { if (!closed) exit 1 }' "$f")" || { echo "$d: no frontmatter (first line --- and a closing ---)"; continue; }
        yq -e 'type == "!!map"' <<< "$fm" >/dev/null 2>&1 || { echo "$d: frontmatter is not valid YAML"; continue; }
        yq -o=json '.' <<< "$fm" | python3 -c "$SKILL_CHECK_PY" "$d"
    done
}

# Codex loads AGENTS.md files root-down and stops at project_doc_max_bytes (32 KiB default) — past it, guidance is cut.
# Checked per file here; a project with nested AGENTS.md must budget the combined size itself.
AGENTS_BUDGET=32768

@test "skills: 스킬 5종이 Agent Skills 규격을 지킨다 (YAML 프론트매터 · name 규칙 · 설명 ≤ 1024자)" {
    require_tool yq
    run skill_violations "$REPO_ROOT/common/skills"
    [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "skills 반증: 길이·문자·하이픈·폴더·타입·구분선 위반을 각각 잡고, 경계값(1024자·한글 1000자)은 통과한다" {
    require_tool yq
    local tmp
    tmp="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    mk() { # dir frontmatter-body
        mkdir -p "$tmp/$1"
        printf -- '---\n%s\n---\n# body\n' "$2" > "$tmp/$1/SKILL.md"
    }
    rep() { head -c "$2" /dev/zero | tr '\0' "$1"; }
    mk long "name: long
description: \"$(rep a 1025)\""
    mk ok "name: ok
description: \"$(rep a 1024)\""
    mk ko "name: ko
description: \"$(printf '가%.0s' $(seq 1000))\""
    mk ko-long "name: ko-long
description: \"$(printf '가%.0s' $(seq 1025))\""
    mk upper "name: Upper
description: x"
    mk other "name: something-else
description: x"
    mk 'a--b' "name: a--b
description: x"
    mk 'a-' "name: a-
description: x"
    mk "$(rep n 65)" "name: $(rep n 65)
description: x"
    mk colon "name: colon
description: Gate: when to run"
    mk nl "name: \"nl\\n\"
description: x"
    mk numdesc "name: numdesc
description: 123"
    mk compat "name: compat
description: x
compatibility: \"$(rep c 501)\""
    mkdir -p "$tmp/unclosed" "$tmp/nofile"
    printf -- '---\nname: unclosed\ndescription: x\n' > "$tmp/unclosed/SKILL.md"
    LC_ALL=C run skill_violations "$tmp"
    local want
    for want in 'long: description length 1025' 'ko-long: description length 1025' "upper: name 'Upper'" \
        "other: name 'something-else' does not match" "a--b: name 'a--b' breaks" "a-: name 'a-' breaks" \
        "$(rep n 65): name" 'colon: frontmatter is not valid YAML' "nl: name 'nl\\n' breaks" \
        'numdesc: description is not a string' 'compat: compatibility must be' 'unclosed: no frontmatter' \
        'nofile: SKILL.md missing'; do
        grep -Fq -- "$want" <<< "$output" || { echo "not caught: $want"; echo "$output"; return 1; }
    done
    ! grep -Eq '^(ok|ko):' <<< "$output" || { echo "boundary rejected: $output"; return 1; }
}

agents_budget_violation() { # file — prints a line when the file alone exceeds the budget
    local size
    size="$(wc -c < "$1")"
    [ "$size" -le "$AGENTS_BUDGET" ] || echo "$1: $size bytes > $AGENTS_BUDGET"
}

@test "context: AGENTS.md 템플릿과 이 저장소의 AGENTS.md 가 Codex 기본 한도 32 KiB 이하" {
    local out
    out="$(agents_budget_violation "$REPO_ROOT/common/templates/AGENTS_TEMPLATE.md")"
    [ -z "$out" ] || { echo "$out"; return 1; }
    out="$(agents_budget_violation "$PROJECT_ROOT/AGENTS.md")"
    [ -z "$out" ] || { echo "$out"; return 1; }
}

@test "context 반증: 32 KiB 를 1바이트 넘긴 AGENTS.md 는 걸리고, 딱 32 KiB 는 통과한다" {
    local f="$BATS_TEST_TMPDIR/AGENTS.md"
    head -c $((AGENTS_BUDGET + 1)) /dev/zero | tr '\0' a > "$f"
    [ -n "$(agents_budget_violation "$f")" ] || { echo "32769 bytes accepted"; return 1; }
    head -c "$AGENTS_BUDGET" /dev/zero | tr '\0' a > "$f"
    [ -z "$(agents_budget_violation "$f")" ] || { echo "32768 bytes rejected"; return 1; }
}
