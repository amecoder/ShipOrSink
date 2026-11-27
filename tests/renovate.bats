#!/usr/bin/env bats
# tests/renovate.bats — Renovate 설정이 로드맵 §5-2 안전 조건을 지킨다 (2단계 A20).
# 하나라도 빠지면 켜지 않는다는 조건이라, 설정을 고쳐 조건을 깨면 여기서 실패한다.
# 실제로 주석이 읽히는지는 CI renovate-config 잡이 Renovate 를 추출 모드로 돌려 확인한다.
# yq 의 `and` 는 조건을 합칠 때 기대와 다르게 평가된다(실측) — 합친 조건은 yq -o=json | jq 로 판정한다.

load helpers

RJ="$PROJECT_ROOT/renovate.json"
WF="$PROJECT_ROOT/.github/workflows/renovate.yml"
CI="$PROJECT_ROOT/.github/workflows/ci.yml"

setup() {
    require_tool jq
    require_tool yq
}

@test "renovate: 자동 머지가 어디에도 없다 — 설정 전체를 재귀로 보고, 자동 머지 프리셋을 끌어오지 못하게 extends 를 고정한다" {
    # recursive: minor/major/vulnerabilityAlerts/packageRules sub-objects included
    run jq -e '[.. | objects | select(.automerge == true or .platformAutomerge == true or .ignoreTests == true)] | length == 0' "$RJ"
    [ "$status" -eq 0 ] || { echo "automerge / platformAutomerge / ignoreTests true somewhere: $(jq -c '[paths(objects and (.automerge == true or .platformAutomerge == true or .ignoreTests == true))]' "$RJ")"; return 1; }
    run jq -e '.platformAutomerge == false and .automerge == false and .extends == ["config:recommended"]' "$RJ"
    [ "$status" -eq 0 ] || { echo "top-level automerge flags or extends changed (presets like :automergeMinor enable automerge)"; return 1; }
}

@test "renovate: .github/** · .claude/** · plugins/sos/standards/common/hooks/** 는 영구히 자동 머지 제외 규칙이 있다" {
    run jq -e '[.packageRules[] | select(.automerge == false and ((.matchFileNames // []) as $m
               | ([".github/**", ".claude/**", "plugins/sos/standards/common/hooks/**"] | all(. as $p | $m | index($p)))))] | length >= 1' "$RJ"
    [ "$status" -eq 0 ] || { echo "no permanent no-automerge rule for .github/** .claude/** common/hooks/**"; return 1; }
}

@test "renovate: 메이저는 대시보드 승인, 공급망 완충(minimumReleaseAge), 대시보드·취약점 알림이 켜져 있다" {
    run jq -e '([.packageRules[] | select((.matchUpdateTypes // []) | index("major")) | select(.dependencyDashboardApproval == true)] | length >= 1)
               and (.minimumReleaseAge | test("^[1-9][0-9]* days?$"))
               and .dependencyDashboard == true and .vulnerabilityAlerts.enabled == true' "$RJ"
    [ "$status" -eq 0 ] || { echo "major approval / minimumReleaseAge / dashboard / vulnerability alerts missing"; return 1; }
}

@test "renovate: 배포 시각이 없는 출처는 영원히 대기하지 않는다 (timestamp-optional) — 시각이 있는 출처는 그대로 기다린다" {
    run jq -e '(.minimumReleaseAgeBehaviour // "timestamp-required") == "timestamp-required"
               and ([.packageRules[] | select(.minimumReleaseAgeBehaviour == "timestamp-optional") | (.matchDatasources // [])[]] | (index("java-version") and index("python-version")))
               and ([.packageRules[] | select(.minimumReleaseAgeBehaviour == "timestamp-optional") | (.matchPackageNames // [])[]] | any(test("mcr")) and any(test("ghcr")))' "$RJ"
    [ "$status" -eq 0 ] || { echo "timestamp-less datasources would wait forever, or the 7-day wait was dropped globally"; return 1; }
}

@test "renovate: 템플릿·테스트 도구가 갱신 대상이다 — common/ 경로, pre-commit, tests/ 를 무시하지 않음, 주석·파일 단위·JSONC customManager" {
    run jq -e '(.["github-actions"].managerFilePatterns | any(test("common/")))
               and (.devcontainer.managerFilePatterns | any(test("devcontainer-templates")))
               and .["pre-commit"].enabled == true
               and .ignorePaths == ["**/node_modules/**"]
               and ([.customManagers[] | select(.matchStrings | any(test("#\\\\s\\*renovate:")))] | length == 1)
               and ([.customManagers[] | select(.matchStrings | any(test("//\\\\s\\*renovate:")))] | length == 1)
               and ([.customManagers[] | select(.managerFilePatterns | any(test("dev-dependencies")))] | length == 1)' "$RJ"
    [ "$status" -eq 0 ] || { echo "a pin location is not covered (config:recommended ignores **/tests/** unless ignorePaths is overridden)"; return 1; }
}

@test "renovate: 여러 곳에 같은 버전이 있어야 하는 핀은 한 PR 로 묶인다 (일치 테스트가 PR 을 빨간불로 만들지 않게)" {
    local g missing=""
    for g in "golangci-lint" "semgrep" "typescript template dev-dependencies" "renovate" \
             "go runtime" "python runtime" "java runtime" "node runtime"; do
        G="$g" jq -e '[.packageRules[] | select(.groupName == env.G)] | length >= 1' "$RJ" >/dev/null || missing="$missing [$g]"
    done
    [ -z "$missing" ] || { echo "missing groups:$missing"; return 1; }
    # each runtime group holds the CI datasource AND the devcontainer image
    for g in go python java node; do
        G="$g runtime" jq -e '[.packageRules[] | select(.groupName == env.G)] | (any(.matchDatasources) and any((.matchPackageNames // []) | any(test("devcontainers"))))' "$RJ" >/dev/null \
            || missing="$missing [$g runtime: CI + devcontainer]"
    done
    [ -z "$missing" ] || { echo "runtime groups do not cover both places:$missing"; return 1; }
}

@test "renovate: PR 이 pr-policy 이슈 연결 검사를 통과하도록 no-issue 라벨을 단다" {
    run jq -e '.labels | index("no-issue")' "$RJ"
    [ "$status" -eq 0 ]
}

@test "renovate 워크플로: 전용 App 토큰으로만, 꺼진 상태로, GITHUB_TOKEN 권한 없이, main 에서만 돈다 (유료 전용 environment 없이)" {
    run yq -e '.jobs.renovate.if == "vars.RENOVATE_ENABLED == '"'"'true'"'"' && github.ref == '"'"'refs/heads/main'"'"'"' "$WF"
    [ "$status" -eq 0 ] || { echo "the job is not gated on vars.RENOVATE_ENABLED and the main branch"; return 1; }
    run bash -c "yq -o=json '.' '$WF' | jq -e '.permissions == {}'"
    [ "$status" -eq 0 ] || { echo "workflow GITHUB_TOKEN permissions are not empty"; return 1; }
    # environment secrets/variables and deployment branches need GitHub Pro+ on private repos — this repo is Free (2026-11-05)
    run yq -e '.jobs.renovate | has("environment") | not' "$WF"
    [ "$status" -eq 0 ] || { echo "the job uses an environment: its secrets are unavailable on GitHub Free private repos"; return 1; }
    run yq -e '.jobs.renovate.steps[] | select(.uses | test("^actions/create-github-app-token@[0-9a-f]{40}")) | .with["private-key"] == "${{ secrets.RENOVATE_APP_PRIVATE_KEY }}"' "$WF"
    [ "$status" -eq 0 ] || { echo "no dedicated App token step"; return 1; }
    run yq -e '.jobs.renovate.steps[] | select(.uses | test("^renovatebot/github-action@[0-9a-f]{40}")) | .with.token == "${{ steps.app-token.outputs.token }}"' "$WF"
    [ "$status" -eq 0 ] || { echo "renovate does not use the App token"; return 1; }
    # values only (comments explain why GITHUB_TOKEN is not used)
    run bash -c "yq '.. | select(tag == \"!!str\")' '$WF' | grep -nE 'GITHUB_TOKEN|github\\.token'"
    [ "$status" -eq 1 ] || { echo "the workflow uses GITHUB_TOKEN: $output"; return 1; }
}

@test "renovate 워크플로: 트리거가 schedule · workflow_dispatch 뿐이고, App 개인 키를 부르는 워크플로는 renovate.yml 하나다" {
    # repo-level secret (Free plan, no environment): any workflow that names it gets it — keep it to this one file
    run bash -c "yq -o=json '.on' '$WF' | jq -e 'keys == [\"schedule\", \"workflow_dispatch\"]'"
    [ "$status" -eq 0 ] || { echo "renovate.yml triggers changed (any extra trigger would run with the App key)"; return 1; }
    local users
    users="$(git -C "$PROJECT_ROOT" grep -lE 'RENOVATE_APP_PRIVATE_KEY' -- '*.yml' '*.yaml' | sort)"
    [ "$users" = ".github/workflows/renovate.yml" ] || { echo "RENOVATE_APP_PRIVATE_KEY referenced by: $users"; return 1; }
}

# Workflows write is a user decision (2026-11-04, roadmap §5-2 addendum) so template copies under .github/ move with
# common/. It is only acceptable together with the digest pin, the main-only job condition and zero automerge above.
@test "renovate 워크플로: App 토큰이 PR 을 만들 수 있는 권한(statuses 쓰기 · checks 읽기)을 갖는다" {
    run bash -c "yq -o=json '.' '$WF' | jq -e '.jobs.renovate.steps[] | select(.uses | test(\"create-github-app-token\")) | .with
               | .[\"permission-contents\"] == \"write\" and .[\"permission-pull-requests\"] == \"write\"
                 and .[\"permission-statuses\"] == \"write\" and .[\"permission-checks\"] == \"read\"'"
    [ "$status" -eq 0 ] || { echo "minimumReleaseAge posts a commit status before the PR exists; without statuses write the run stops"; return 1; }
}

@test "renovate 이미지: 태그와 다이제스트로 고정하고, 워크플로와 CI 검증이 같은 이미지를 쓴다" {
    local wf ci
    wf="$(yq -r '.["env"].RENOVATE_VERSION' "$WF")"
    ci="$(yq -r '.["env"].RENOVATE_VERSION' "$CI")"
    [[ "$wf" =~ ^[0-9]+\.[0-9]+\.[0-9]+@sha256:[0-9a-f]{64}$ ]] || { echo "renovate.yml image not tag@digest: [$wf]"; return 1; }
    [ "$wf" = "$ci" ] || { echo "renovate.yml [$wf] != ci.yml [$ci]"; return 1; }
}

@test "ci: renovate-config 잡이 고정 이미지로 설정 검증과 저장소 전체 주석 추출 확인을 하고, ruleset 필수 체크에 들어 있다" {
    run yq -e '[.jobs["renovate-config"].steps[] | select((.run // "") | test("renovate:\\$\\{RENOVATE_VERSION\\}\" renovate-config-validator --strict"))] | length == 1' "$CI"
    [ "$status" -eq 0 ] || { echo "renovate-config job does not run the validator from the pinned image"; return 1; }
    run bash -c "yq -o=json '.' '$CI' | jq -e '[.jobs[\"renovate-config\"].steps[] | select((.run // \"\") | test(\"--dry-run=extract\") and test(\"git grep -lE\"))] | length == 1'"
    [ "$status" -eq 0 ] || { echo "renovate-config job does not run the repo-wide extraction check"; return 1; }
    run jq -e '[.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | index("renovate-config")' "$PROJECT_ROOT/.github/rulesets/main-protection.json"
    [ "$status" -eq 0 ]
}

@test "ci: bats 잡에 읽기 전용 토큰이 있어 SHA 핀 실존 검사가 CI 에서 건너뛰지 않는다" {
    run bash -c "yq -o=json '.' '$CI' | jq -e '(.jobs.bats.steps[] | select(.name == \"Run bats\") | .env.GH_TOKEN) == \"\${{ github.token }}\" and .permissions == {\"contents\": \"read\"}'"
    [ "$status" -eq 0 ] || { echo "bats job has no read-only GH_TOKEN, or the workflow token is wider than contents: read"; return 1; }
}
