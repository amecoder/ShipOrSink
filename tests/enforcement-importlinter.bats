#!/usr/bin/env bats
# tests/enforcement-importlinter.bats — Python 템플릿의 import-linter 계약이 실제로 막는지 실행 결과로 판정 (로드맵 A11).
# 배포 템플릿 python/templates/pyproject-quality.toml 을 그대로 fixture 프로젝트의 pyproject.toml 로 쓰고,
# CI 템플릿(common/ci-templates/ci-python.yml) lint 잡의 "Import contracts" 단계와 같은 버전·PYTHONPATH 로 lint-imports 를 돌린다.
#   정상 onion 샘플(src/app/{domain,application,adapter/web,adapter/persistence})은 통과
#   domain → adapter · application → adapter · domain → 프레임워크 · adapter ↔ adapter 는 해당 계약이 BROKEN 으로 실패
#   계층 패키지가 없으면 실패(이름 오타 방지) · 괄호로 감싼 선택 계층은 없어도 통과
#   반증: 금지 계약을 뺀 템플릿에서는 domain → fastapi 가 통과한다
# uvx 가 있어야 한다(첫 실행은 PyPI 에서 import-linter 를 받는다).

load helpers

PY_TPL="$REPO_ROOT/python/templates"
CI_PY="$REPO_ROOT/common/ci-templates/ci-python.yml"
STEP='Import contracts (import-linter)'

setup() {
    require_tool uvx
    require_tool yq
}

ci_env() { # name
    V="$1" yq -r '.env[strenv(V)]' "$CI_PY"
}

# A fresh project with the template pyproject and a clean onion layout under src/app; prints its path.
il_project() {
    local dir m
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp "${TPL_FILE:-$PY_TPL/pyproject-quality.toml}" "$dir/pyproject.toml"
    for m in app app/domain app/application app/adapter app/adapter/web app/adapter/persistence; do
        mkdir -p "$dir/src/$m"
        : > "$dir/src/$m/__init__.py"
    done
    printf 'from dataclasses import dataclass\n\n\n@dataclass(frozen=True)\nclass Order:\n    amount: int\n' \
        > "$dir/src/app/domain/model.py"
    printf 'from app.domain.model import Order\n\n\ndef total(order: Order) -> int:\n    return order.amount\n' \
        > "$dir/src/app/application/service.py"
    printf 'from app.application.service import total\n\nROUTES = [total]\n' > "$dir/src/app/adapter/web/routes.py"
    printf 'from app.domain.model import Order\n\nSTORE: list[Order] = []\n' > "$dir/src/app/adapter/persistence/repo.py"
    echo "$dir"
}

# Runs the check the way the CI step does: pinned version from the CI env, PYTHONPATH = the step's env.
il_rc() { # dir
    local ver pp
    ver="$(ci_env IMPORT_LINTER_VERSION)"
    pp="$(S="$STEP" yq -r '.jobs.lint.steps[] | select(.name == strenv(S)) | .env.PYTHONPATH' "$CI_PY")"
    pp="${pp//\$\{\{ env.SRC_DIR \}\}/$(ci_env SRC_DIR)}"
    [ -n "$ver" ] && [ "$ver" != null ] && [ "$pp" != null ] || { echo "CI step '$STEP' or its version/PYTHONPATH missing"; return 2; }
    (cd "$1" && PYTHONPATH="$pp" uvx -q --from "import-linter==$ver" lint-imports 2>&1)
}

# Expects failure with the named contract BROKEN and the offending import listed.
expect_broken() { # dir contract-name import-fragment
    run il_rc "$1"
    [ "$status" -ne 0 ] || { echo "violation accepted: $output"; return 1; }
    grep -Fq "$2 BROKEN" <<< "$output" || { echo "contract '$2' not BROKEN: $output"; return 1; }
    grep -Fq -- "$3" <<< "$output" || { echo "offending import '$3' not reported: $output"; return 1; }
}

@test "importlinter: 정상 onion 구조는 계약 3개가 모두 KEPT 로 통과한다" {
    run il_rc "$(il_project)"
    [ "$status" -eq 0 ] || { echo "clean layout rejected: $output"; return 1; }
    [ "$(grep -c ' KEPT$' <<< "$output")" -eq 3 ] || { echo "expected 3 KEPT contracts: $output"; return 1; }
}

@test "importlinter: domain 이 adapter 를 import 하면 계층 계약이 실패한다" {
    local d
    d="$(il_project)"
    echo 'from app.adapter.web import routes  # noqa: F401' >> "$d/src/app/domain/model.py"
    expect_broken "$d" "Onion layers: adapter -> application -> domain" "app.domain.model -> app.adapter.web"
}

@test "importlinter: application 이 adapter 를 import 하면 계층 계약이 실패한다" {
    local d
    d="$(il_project)"
    echo 'from app.adapter.persistence import repo  # noqa: F401' >> "$d/src/app/application/service.py"
    expect_broken "$d" "Onion layers: adapter -> application -> domain" "app.application.service -> app.adapter.persistence"
}

@test "importlinter: domain 이 웹·ORM 프레임워크를 import 하면 금지 계약이 실패한다(설치돼 있지 않아도)" {
    local d f
    for f in fastapi sqlalchemy; do
        d="$(il_project)"
        echo "import $f  # noqa: F401" >> "$d/src/app/domain/model.py"
        expect_broken "$d" "Domain has no framework imports" "app.domain.model -> $f"
    done
}

@test "importlinter: 어댑터끼리 import 하면 독립 계약이 실패한다" {
    local d
    d="$(il_project)"
    echo 'from app.adapter.persistence import repo  # noqa: F401' >> "$d/src/app/adapter/web/routes.py"
    expect_broken "$d" "Adapters do not import each other" "app.adapter.web.routes -> app.adapter.persistence"
}

@test "importlinter: 계층 패키지가 없으면 실패하고, 괄호로 감싼 선택 계층은 없어도 통과한다" {
    local d tpl
    d="$(il_project)"
    rm -r "$d/src/app/application"
    sed_i 's|^from app.application.service import total|from app.domain.model import Order as total|' "$d/src/app/adapter/web/routes.py"
    run il_rc "$d"
    [ "$status" -ne 0 ] || { echo "missing layer accepted: $output"; return 1; }
    grep -Fq "app.application does not exist" <<< "$output" || { echo "missing layer not reported: $output"; return 1; }
    tpl="$BATS_TEST_TMPDIR/optional.toml"
    sed 's|^layers = \["adapter", "application", "domain"\]|layers = ["adapter", "(application)", "domain"]|' \
        "$PY_TPL/pyproject-quality.toml" > "$tpl"
    ! cmp -s "$tpl" "$PY_TPL/pyproject-quality.toml" || { echo "template layers line not found"; return 1; }
    cp "$tpl" "$d/pyproject.toml"
    run il_rc "$d"
    [ "$status" -eq 0 ] || { echo "optional layer rejected: $output"; return 1; }
}

@test "importlinter: 패키지 이름(\"app\")을 바꾸지 않은 프로젝트는 조용히 통과하지 않고 실패한다" {
    local d
    d="$(il_project)"
    mv "$d/src/app" "$d/src/shop"
    run il_rc "$d"
    [ "$status" -ne 0 ] || { echo "unconfigured template accepted: $output"; return 1; }
    grep -Fq "Could not find package 'app'" <<< "$output" || { echo "unclear failure: $output"; return 1; }
}

@test "importlinter: 반증 — 금지 계약을 뺀 템플릿에서는 domain → fastapi 가 통과한다" {
    local d
    TPL_FILE="$BATS_TEST_TMPDIR/no-forbidden.toml"
    awk '/^\[\[tool.importlinter.contracts\]\]/ { blk = $0; skip = 0; next }
         blk != "" && /^name = "Domain has no framework imports"/ { skip = 1 }
         blk != "" { if (!skip) print blk; blk = "" }
         skip && /^$/ { skip = 0 }
         !skip { print }' "$PY_TPL/pyproject-quality.toml" > "$TPL_FILE"
    ! grep -Fq "Domain has no framework imports" "$TPL_FILE" || { echo "forbidden contract not removed"; return 1; }
    d="$(il_project)"
    echo 'import fastapi  # noqa: F401' >> "$d/src/app/domain/model.py"
    run il_rc "$d"
    [ "$status" -eq 0 ] || { echo "still rejected without the forbidden contract: $output"; return 1; }
}

@test "importlinter: CI lint 잡이 고정 버전 import-linter 로 계약을 검사하고, 건너뛸 수 없다" {
    local step
    step="$(S="$STEP" yq -r '.jobs.lint.steps[] | select(.name == strenv(S)) | .run' "$CI_PY")"
    grep -Fq 'pip install "import-linter==${{ env.IMPORT_LINTER_VERSION }}"' <<< "$step" \
        || { echo "pinned import-linter install missing: $step"; return 1; }
    grep -Eq '^lint-imports$' <<< "$step" || { echo "lint-imports not run: $step"; return 1; }
    run env S="$STEP" yq -e '.jobs.lint.steps[] | select(.name == strenv(S))
        | (has("if") or has("continue-on-error") or (.run | test("\\|\\| *true|; *true"))) | not' "$CI_PY"
    [ "$status" -eq 0 ] || { echo "import contracts step can be skipped or ignored: $output"; return 1; }
}
