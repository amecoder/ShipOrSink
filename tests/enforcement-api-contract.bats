#!/usr/bin/env bats
# tests/enforcement-api-contract.bats — API 계약 깨짐 검사가 실제로 막는지 실행 결과로 판정 (로드맵 A13).
# CI 템플릿 common/ci-templates/ci-api-contract.yml 의 두 단계 run 블록을 그대로 꺼내, 기준 브랜치(main)와
# PR 브랜치를 가진 fixture git 저장소에서 같은 env(OPENAPI_SPECS · PROTO_DIR · BASE_REF)로 실행한다.
#   OpenAPI(oasdiff): 바뀐 것 없음·필드 추가는 통과 · 응답 필수 필드 삭제는 실패(분리된 $ref 파일 포함)
#   Protobuf(buf):    바뀐 것 없음·필드 추가는 통과 · 필드 삭제는 실패
#   기준 브랜치에 아직 없는 스펙(처음 추가하는 PR)은 알림만 · 지금 트리에 없는 경로는 실패(경로 오타가 조용히 통과하지 않게)
#   반증: --fail-on ERR 을 뺀 oasdiff 는 필드 삭제를 통과시킨다
# 도구: PATH 의 oasdiff·buf 또는 OASDIFF·BUF(실행 파일 경로) — 버전은 워크플로 env 와 같아야 한다.

load helpers

CI_API="$REPO_ROOT/common/ci-templates/ci-api-contract.yml"
OAS_STEP='Breaking changes (oasdiff)'
BUF_STEP='Breaking changes (buf)'

setup() {
    require_tool yq
    require_tool "${OASDIFF:-oasdiff}"
    require_tool "${BUF:-buf}"
    PATH="$(dirname "$(command -v "${OASDIFF:-oasdiff}")"):$(dirname "$(command -v "${BUF:-buf}")"):$PATH"
    export BUF_CACHE_DIR="$BATS_FILE_TMPDIR/buf-cache"
    # the Claude Code sandbox injects GIT_CONFIG_* pairs that break the git clone buf runs internally
    local v
    for v in $(env | sed -n 's/^\(GIT_CONFIG[A-Z_0-9]*\)=.*/\1/p'); do unset "$v"; done
}

wf_env() { # name
    V="$1" yq -r '.env[strenv(V)]' "$CI_API"
}

step_run() { # job step-name
    J="$1" S="$2" yq -r '.jobs[strenv(J)].steps[] | select(.name == strenv(S)) | .run' "$CI_API"
}

openapi_yaml() { # schema-ref-or-inline
    cat <<EOF
openapi: 3.0.3
info: {title: Orders, version: "1.0.0"}
paths:
  /orders/{id}:
    get:
      operationId: getOrder
      parameters:
        - {name: id, in: path, required: true, schema: {type: string}}
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
$1
EOF
}

INLINE_ORDER='                type: object
                required: [id, amount]
                properties:
                  id: {type: string}
                  amount: {type: integer}'

ORDER_PROTO='syntax = "proto3";
package orders.v1;
message Order {
  string id = 1;
  int64 amount = 2;
}'

# A git repo whose main branch holds the base contracts (or none, with "empty"); leaves branch pr checked out.
# Prints its path.
contract_repo() { # base: full | empty
    local dir
    dir="$(make_git_repo)"
    if [ "$1" = full ]; then
        openapi_yaml "$INLINE_ORDER" > "$dir/openapi.yaml"
        mkdir -p "$dir/proto/orders/v1"
        printf 'version: v2\nbreaking:\n  use:\n    - FILE\n' > "$dir/proto/buf.yaml"
        printf '%s\n' "$ORDER_PROTO" > "$dir/proto/orders/v1/order.proto"
        git -C "$dir" add -A
        git -C "$dir" commit -q -m base
    fi
    git -C "$dir" checkout -q -b pr
    echo "$dir"
}

commit_all() { # dir
    git -C "$1" add -A
    git -C "$1" commit -q -m change
}

# Runs one CI step's run block the way Actions does (bash -e), with the workflow env and BASE_REF=main.
run_step() { # dir job step-name
    local body
    body="$(step_run "$2" "$3")"
    [ -n "$body" ] && [ "$body" != null ] || { echo "CI step '$3' missing in job '$2'"; return 2; }
    (cd "$1" && OPENAPI_SPECS="${SPECS:-$(wf_env OPENAPI_SPECS)}" PROTO_DIR="${PDIR:-$(wf_env PROTO_DIR)}" \
        BASE_REF=main bash -e -c "$body" 2>&1)
}

drop_amount_openapi() { # file
    sed_i '/amount: {type: integer}/d; s/required: \[id, amount\]/required: [id]/' "$1"
}

@test "api-contract: 워크플로 env 의 도구 버전이 테스트가 쓰는 바이너리와 같다" {
    local ov bv
    ov="$(wf_env OASDIFF_VERSION)"
    bv="$(wf_env BUF_VERSION)"
    [ "$(oasdiff --version)" = "oasdiff version $ov" ] || { echo "oasdiff $(oasdiff --version) != $ov"; return 1; }
    [ "$(buf --version)" = "$bv" ] || { echo "buf $(buf --version) != $bv"; return 1; }
}

@test "api-contract: PR 에서만 돌고 기준 브랜치 비교에 필요한 전체 이력을 받는다" {
    [ "$(yq -r '.on | keys | join(",")' "$CI_API")" = pull_request ]
    local j
    for j in openapi protobuf; do
        [ "$(J="$j" yq -r '.jobs[strenv(J)].steps[] | select(.uses == "actions/checkout*") | .with["fetch-depth"]' "$CI_API")" = 0 ] \
            || { echo "$j: checkout fetch-depth is not 0"; return 1; }
        [ "$(J="$j" yq -r '.jobs[strenv(J)].steps[] | select(.name == "Breaking changes*") | .env.BASE_REF' "$CI_API")" = 'origin/${{ github.base_ref }}' ] \
            || { echo "$j: BASE_REF is not origin/<base_ref>"; return 1; }
    done
}

@test "oasdiff: 바뀐 것 없음 · 선택 필드 추가는 통과" {
    dir="$(contract_repo full)"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    perl -pi -e 's/(                  amount: \{type: integer\})/$1\n                  note: {type: string}/' "$dir/openapi.yaml"
    commit_all "$dir"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -eq 0 ] || { echo "additive change rejected: $output"; return 1; }
}

@test "oasdiff: 응답 필수 필드를 지우면 실패한다" {
    dir="$(contract_repo full)"
    drop_amount_openapi "$dir/openapi.yaml"
    commit_all "$dir"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -ne 0 ] || { echo "field removal accepted: $output"; return 1; }
    grep -Fq 'response-required-property-removed' <<< "$output" || { echo "rule not reported: $output"; return 1; }
}

@test "oasdiff: 분리된 \$ref 파일에서 필드를 지워도 실패한다 (기준 쪽 참조 파일도 git 에서 읽는다)" {
    dir="$(make_git_repo)"
    mkdir -p "$dir/api"
    openapi_yaml "                \$ref: './schemas.yaml#/Order'" > "$dir/api/openapi.yaml"
    printf 'Order:\n  type: object\n  required: [id, amount]\n  properties:\n    id: {type: string}\n    amount: {type: integer}\n' \
        > "$dir/api/schemas.yaml"
    commit_all "$dir"
    git -C "$dir" checkout -q -b pr
    drop_amount_openapi "$dir/api/schemas.yaml"
    commit_all "$dir"
    SPECS=api/openapi.yaml run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -ne 0 ] || { echo "removal in referenced file accepted: $output"; return 1; }
    grep -Fq 'response-required-property-removed' <<< "$output"
}

@test "oasdiff: 기준 브랜치에 없는 새 스펙은 알림만 남기고 통과" {
    dir="$(contract_repo empty)"
    openapi_yaml "$INLINE_ORDER" > "$dir/openapi.yaml"
    commit_all "$dir"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    grep -Fq '::notice::' <<< "$output" || { echo "no notice for new spec: $output"; return 1; }
}

@test "oasdiff: 지금 트리에 없는 스펙 경로는 실패한다 (OPENAPI_SPECS 오타가 조용히 통과하지 않게)" {
    dir="$(contract_repo full)"
    SPECS="openapi.yaml api/missing.yaml" run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -ne 0 ] || { echo "missing spec accepted: $output"; return 1; }
    grep -Fq 'api/missing.yaml' <<< "$output"
}

@test "oasdiff 반증: --fail-on ERR 를 빼면 필드 삭제가 통과한다 (플래그가 실패의 원인)" {
    dir="$(contract_repo full)"
    drop_amount_openapi "$dir/openapi.yaml"
    commit_all "$dir"
    grep -Fq -- '--fail-on ERR' <<< "$(step_run openapi "$OAS_STEP")" || { echo "step has no --fail-on ERR"; return 1; }
    run bash -c "cd '$dir' && oasdiff breaking main:openapi.yaml openapi.yaml"
    [ "$status" -eq 0 ] || { echo "oasdiff without --fail-on failed: $output"; return 1; }
}

@test "buf: 바뀐 것 없음 · 필드 추가는 통과" {
    dir="$(contract_repo full)"
    run run_step "$dir" protobuf "$BUF_STEP"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    perl -pi -e 's/(  int64 amount = 2;)/$1\n  string note = 3;/' "$dir/proto/orders/v1/order.proto"
    commit_all "$dir"
    run run_step "$dir" protobuf "$BUF_STEP"
    [ "$status" -eq 0 ] || { echo "additive change rejected: $output"; return 1; }
}

@test "buf: 필드를 지우면 실패한다" {
    dir="$(contract_repo full)"
    sed_i '/int64 amount/d' "$dir/proto/orders/v1/order.proto"
    commit_all "$dir"
    run run_step "$dir" protobuf "$BUF_STEP"
    [ "$status" -ne 0 ] || { echo "field deletion accepted: $output"; return 1; }
    grep -Fq 'Previously present field "2" with name "amount"' <<< "$output" || { echo "deletion not reported: $output"; return 1; }
}

@test "buf: 기준 브랜치에 없는 새 proto 폴더는 알림만 남기고 통과" {
    dir="$(contract_repo empty)"
    mkdir -p "$dir/proto/orders/v1"
    printf '%s\n' "$ORDER_PROTO" > "$dir/proto/orders/v1/order.proto"
    commit_all "$dir"
    run run_step "$dir" protobuf "$BUF_STEP"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    grep -Fq '::notice::' <<< "$output"
}

@test "buf: 지금 트리에 .proto 가 없는 PROTO_DIR 은 실패한다" {
    dir="$(contract_repo full)"
    PDIR=protos run run_step "$dir" protobuf "$BUF_STEP"
    [ "$status" -ne 0 ] || { echo "missing proto dir accepted: $output"; return 1; }
    grep -Fq 'protos' <<< "$output"
}

@test "api-contract: 이 저장소 CI 의 bats 잡이 템플릿과 같은 버전을 설치한다" {
    local ci="$PROJECT_ROOT/.github/workflows/ci.yml" n
    for n in OASDIFF_VERSION BUF_VERSION; do
        [ "$(V="$n" yq -r '.env[strenv(V)]' "$ci")" = "$(wf_env "$n")" ] || { echo "$n differs between ci.yml and the template"; return 1; }
    done
    yq -r '.jobs[].steps[].name' "$ci" | grep -Fxq 'Install API contract tools (oasdiff, buf — pinned + sha256)'
}

@test "api-contract: 실제 Actions 처럼 clone 한 detached HEAD 에서 origin/main 을 기준으로 깨짐을 잡는다" {
    local src dir body
    src="$(contract_repo full)"
    drop_amount_openapi "$src/openapi.yaml"
    sed_i '/int64 amount/d' "$src/proto/orders/v1/order.proto"
    commit_all "$src"
    dir="$BATS_TEST_TMPDIR/clone"
    git clone -q "$src" "$dir"
    git -C "$dir" checkout -q --detach origin/pr
    for job in openapi:"$OAS_STEP" protobuf:"$BUF_STEP"; do
        body="$(step_run "${job%%:*}" "${job#*:}")"
        run bash -c "cd '$dir' && OPENAPI_SPECS=openapi.yaml PROTO_DIR=proto BASE_REF=origin/main bash -e -c \"\$0\"" "$body"
        [ "$status" -ne 0 ] || { echo "${job%%:*}: breaking change accepted against origin/main: $output"; return 1; }
    done
}

@test "oasdiff: 글롭 경로는 거부한다 (PR 트리에서만 펼쳐져 지워진 스펙을 놓친다)" {
    dir="$(contract_repo full)"
    SPECS='*.yaml' run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -ne 0 ] || { echo "glob accepted: $output"; return 1; }
    grep -Fq 'explicit paths' <<< "$output"
}

@test "oasdiff: PR 에서 스펙 파일을 지우면 '삭제' 로 실패한다" {
    dir="$(contract_repo full)"
    git -C "$dir" rm -q openapi.yaml
    git -C "$dir" commit -q -m drop
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -ne 0 ] || { echo "spec deletion accepted: $output"; return 1; }
    grep -Fq 'was deleted in this PR' <<< "$output" || { echo "deletion not named: $output"; return 1; }
}

@test "oasdiff 특성: 응답의 선택 필드 삭제와 deprecated 필드 삭제는 통과한다 (문서화된 한계 — 바뀌면 문서도 고친다)" {
    dir="$(contract_repo full)"
    sed_i 's/required: \[id, amount\]/required: [id]/' "$dir/openapi.yaml"
    commit_all "$dir"
    git -C "$dir" branch -f main HEAD
    sed_i '/amount: {type: integer}/d' "$dir/openapi.yaml"
    commit_all "$dir"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -eq 0 ] || { echo "optional removal now fails — update docs: $output"; return 1; }

    dir="$(contract_repo full)"
    sed_i 's/amount: {type: integer}/amount: {type: integer, deprecated: true}/' "$dir/openapi.yaml"
    commit_all "$dir"
    git -C "$dir" branch -f main HEAD
    sed_i '/amount: {type: integer, deprecated: true}/d; s/required: \[id, amount\]/required: [id]/' "$dir/openapi.yaml"
    commit_all "$dir"
    run run_step "$dir" openapi "$OAS_STEP"
    [ "$status" -eq 0 ] || { echo "deprecated removal now fails — update docs: $output"; return 1; }
}
