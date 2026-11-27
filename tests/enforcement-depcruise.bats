#!/usr/bin/env bats
# tests/enforcement-depcruise.bats — TypeScript 템플릿의 dependency-cruiser 규칙이 실제로 막는지 실행 결과로 판정 (로드맵 A12).
# 배포 템플릿 typescript-react/templates/.dependency-cruiser.cjs 를 그대로 fixture 프로젝트에 넣고,
# CI 템플릿(common/ci-templates/ci-typescript.yml) lint 잡의 "Dependency rules" 단계와 같은 명령(depcruise src --config …)을 돌린다.
#   정상 Next.js 모양(src/{domain,application,components,app})은 통과 · 순환 · domain → 바깥 폴더 · domain → react/next
#   · application → 바깥 폴더는 해당 규칙 이름으로 실패 · src/domain 이 없는 프로젝트는 오탐 없이 통과
#   반증: no-circular 를 warn 으로 낮춘 설정에서는 순환이 통과한다
# 도구는 tests/enforcement-ts/package-lock.json 을 TS_TOOLS_DIR 에 npm ci 한 것 (tests/enforcement.bats 와 같은 방식).

load helpers

TS_TPL="$REPO_ROOT/typescript-react/templates"
CI_TS="$REPO_ROOT/common/ci-templates/ci-typescript.yml"
STEP='Dependency rules (dependency-cruiser)'

require_depcruise() {
    if [ -n "${TS_TOOLS_DIR:-}" ] && [ -x "$TS_TOOLS_DIR/node_modules/.bin/depcruise" ]; then
        return 0
    fi
    if [ "${TEMPLATE_TOOLS_REQUIRED:-0}" = "1" ]; then
        echo "TS_TOOLS_DIR with depcruise missing (npm ci tests/enforcement-ts into it)" >&2
        return 1
    fi
    skip "TS_TOOLS_DIR not set up (cp tests/enforcement-ts/package*.json \$TS_TOOLS_DIR && npm ci --prefix \$TS_TOOLS_DIR)"
}

# A Next.js-shaped project with the template config and a clean onion layout; prints its path.
dc_project() {
    local d
    d="$(mktemp -d -p "$BATS_TEST_TMPDIR" dc.XXXXXX)"
    mkdir -p "$d/src/domain" "$d/src/application" "$d/src/components" "$d/src/app"
    ln -s "$TS_TOOLS_DIR/node_modules" "$d/node_modules"
    cp "${DC_CONFIG:-$TS_TPL/.dependency-cruiser.cjs}" "$d/.dependency-cruiser.cjs"
    printf '{"compilerOptions":{"strict":true,"module":"ESNext","moduleResolution":"Bundler","jsx":"react-jsx","noEmit":true},"include":["src"]}\n' \
        > "$d/tsconfig.json"
    echo 'export interface Order { amount: number }' > "$d/src/domain/order.ts"
    printf 'import type { Order } from "../domain/order";\nexport const total = (o: Order): number => o.amount;\n' \
        > "$d/src/application/total.ts"
    printf '%s\n' 'import { useState } from "react";' 'import { total } from "../application/total";' \
        'export function Price() { const [o] = useState({ amount: 1 }); return <span>{total(o)}</span>; }' \
        > "$d/src/components/Price.tsx"
    printf 'import { Price } from "../components/Price";\nexport default function Page() { return <Price />; }\n' \
        > "$d/src/app/page.tsx"
    echo "$d"
}

# The CI step's command, run as-is in the project (npm branch: npx resolves the local depcruise).
dc_rc() { # dir
    local cmd
    cmd="$(S="$STEP" yq -r '.jobs.lint.steps[] | select(.name == strenv(S)) | .run' "$CI_TS" | sed -nE 's/^[[:space:]]*npx --no (depcruise .*)$/\1/p')"
    [ -n "$cmd" ] || { echo "npm branch of CI step '$STEP' not found"; return 2; }
    (cd "$1" && PATH="$TS_TOOLS_DIR/node_modules/.bin:$PATH" bash -e -c "$cmd" 2>&1)
}

expect_violation() { # dir rule-name from-fragment
    run dc_rc "$1"
    [ "$status" -ne 0 ] || { echo "violation accepted: $output"; return 1; }
    grep -Eq "error $2: $3" <<< "$output" || { echo "rule $2 did not report $3: $output"; return 1; }
}

@test "depcruise: 정상 onion 구조(Next.js 모양)는 위반 0 으로 통과한다" {
    require_depcruise
    run dc_rc "$(dc_project)"
    [ "$status" -eq 0 ] || { echo "clean layout rejected: $output"; return 1; }
    grep -Fq "no dependency violations found" <<< "$output" || { echo "unexpected output: $output"; return 1; }
}

@test "depcruise: 순환 의존은 no-circular 로 실패한다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf 'import { b } from "./b";\nexport const a = (): number => b();\n' > "$d/src/components/a.ts"
    printf 'import { a } from "./a";\nexport const b = (): number => a();\n' > "$d/src/components/b.ts"
    expect_violation "$d" no-circular "src/components/(a|b)\.ts"
}

@test "depcruise: domain 이 바깥 폴더(components)를 import 하면 실패한다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf 'import { Price } from "../components/Price";\nexport const x = Price;\n' > "$d/src/domain/bad.ts"
    expect_violation "$d" domain-no-outer-layers "src/domain/bad\.ts → src/components/Price\.tsx"
}

@test "depcruise: domain 이 react·next 를 import 하면(타입만이어도) 실패한다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf 'import { useState } from "react";\nexport const z = useState;\n' > "$d/src/domain/hook.ts"
    printf 'import type { NextPage } from "next";\nexport type P = NextPage;\n' > "$d/src/domain/page.ts"
    expect_violation "$d" domain-no-framework "src/domain/hook\.ts → .*react"
    expect_violation "$d" domain-no-framework "src/domain/page\.ts → .*next"
}

@test "depcruise: Next.js 경로 별칭(@/…)으로 import 해도 domain 규칙이 잡는다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf '{"compilerOptions":{"strict":true,"module":"ESNext","moduleResolution":"Bundler","jsx":"react-jsx","noEmit":true,"paths":{"@/*":["./src/*"]}},"include":["src"]}\n' \
        > "$d/tsconfig.json"
    printf 'import { Price } from "@/components/Price";\nexport const x = Price;\n' > "$d/src/domain/alias.ts"
    expect_violation "$d" domain-no-outer-layers "src/domain/alias\.ts → src/components/Price\.tsx"
}

@test "depcruise: application 이 바깥 폴더(app)를 import 하면 실패한다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf 'import Page from "../app/page";\nexport const y = Page;\n' > "$d/src/application/bad.ts"
    expect_violation "$d" application-no-outer-layers "src/application/bad\.ts → src/app/page\.tsx"
}

@test "depcruise: src/domain 이 없는 프로젝트는 계층 규칙에 걸리지 않는다(순환 검사만)" {
    require_depcruise
    local d
    d="$(dc_project)"
    rm -r "$d/src/domain" "$d/src/application"
    printf 'export function Price() { return <span>1</span>; }\n' > "$d/src/components/Price.tsx"
    run dc_rc "$d"
    [ "$status" -eq 0 ] || { echo "project without domain layer rejected: $output"; return 1; }
}

@test "depcruise: src/ 가 없는 루트 레이아웃(app/ · domain/ 을 루트에)도 실행되고, 같은 규칙이 걸린다" {
    require_depcruise
    local d
    d="$(dc_project)"
    mv "$d/src/"* "$d/" && rmdir "$d/src"
    sed_i 's/"include":\["src"\]/"include":["**\/*.ts","**\/*.tsx"]/' "$d/tsconfig.json"   # what create-next-app writes
    run dc_rc "$d"
    [ "$status" -eq 0 ] || { echo "clean root layout rejected: $output"; return 1; }
    printf 'import { Price } from "../components/Price";\nexport const x = Price;\n' > "$d/domain/bad.ts"
    expect_violation "$d" domain-no-outer-layers "domain/bad\.ts → components/Price\.tsx"
}

@test "depcruise: domain·application 의 import 를 풀지 못하면(별칭 설정 누락 등) 조용히 통과하지 않는다" {
    require_depcruise
    local d
    d="$(dc_project)"
    printf 'import { Price } from "@/components/Price";\nexport const x = Price;\n' > "$d/src/domain/alias.ts"
    printf 'import { util } from "~/lib/util";\nexport const y = util;\n' > "$d/src/application/alias.ts"
    expect_violation "$d" layers-no-unresolvable "src/domain/alias\.ts → @/components/Price"
    expect_violation "$d" layers-no-unresolvable "src/application/alias\.ts → ~/lib/util"
}

@test "depcruise: 반증 — no-circular 를 warn 으로 낮춘 설정에서는 순환이 통과한다" {
    require_depcruise
    local d
    DC_CONFIG="$BATS_TEST_TMPDIR/warn.cjs"
    sed '/name: "no-circular"/,/}/s/severity: "error"/severity: "warn"/' "$TS_TPL/.dependency-cruiser.cjs" > "$DC_CONFIG"
    ! cmp -s "$DC_CONFIG" "$TS_TPL/.dependency-cruiser.cjs" || { echo "no-circular severity line not found"; return 1; }
    d="$(dc_project)"
    printf 'import { b } from "./b";\nexport const a = (): number => b();\n' > "$d/src/components/a.ts"
    printf 'import { a } from "./a";\nexport const b = (): number => a();\n' > "$d/src/components/b.ts"
    run dc_rc "$d"
    [ "$status" -eq 0 ] || { echo "cycle still rejected with warn severity: $output"; return 1; }
}

@test "depcruise: CI lint 잡이 pnpm·npm 모두에서 같은 설정으로 규칙을 검사하고, 건너뛸 수 없다" {
    local run_
    run_="$(S="$STEP" yq -r '.jobs.lint.steps[] | select(.name == strenv(S)) | .run' "$CI_TS")"
    grep -Eq '^[[:space:]]*pnpm exec depcruise \. --config \.dependency-cruiser\.cjs$' <<< "$run_" \
        || { echo "pnpm branch missing: $run_"; return 1; }
    # --no: never fetch an unpinned depcruise from the registry when the devDependency is missing
    grep -Eq '^[[:space:]]*npx --no depcruise \. --config \.dependency-cruiser\.cjs$' <<< "$run_" \
        || { echo "npm branch missing: $run_"; return 1; }
    run env S="$STEP" yq -e '.jobs.lint.steps[] | select(.name == strenv(S))
        | (has("if") or has("continue-on-error") or (.run | test("\\|\\| *true|; *true"))) | not' "$CI_TS"
    [ "$status" -eq 0 ] || { echo "dependency rules step can be skipped or ignored: $output"; return 1; }
}

@test "depcruise: bootstrap 이 설정 파일을 복사하고, 고정 버전 목록에 dependency-cruiser 가 있다" {
    grep -Fq 'cp "$TPL_DIR/.dependency-cruiser.cjs" .dependency-cruiser.cjs' "$REPO_ROOT/typescript-react/bootstrap.sh" \
        || { echo "bootstrap does not copy .dependency-cruiser.cjs"; return 1; }
    grep -Eq '^dependency-cruiser@[0-9]+\.[0-9]+\.[0-9]+$' "$TS_TPL/dev-dependencies.txt" \
        || { echo "dependency-cruiser not pinned in dev-dependencies.txt"; return 1; }
}
