#!/usr/bin/env bats
# tests/devcontainer.bats — devcontainer 템플릿이 갱신되는 이미지 계열을 가리키고, 언어 버전이 CI 템플릿과 같은지 확인한다.
# 근거: 2026-11-04 실측 — 이미지 메이저 `1-` 태그 5개가 2025-05~09 빌드 이후 재빌드되지 않았다(언어 버전이 지원 중이어도 OS 패치 중단).
# 태그 형식: <이미지 메이저>-<언어 버전>-<OS> (예: go:2-1.26-bookworm)
# 최신성 검사는 시계·외부 레지스트리에 의존해 PR 게이트에 두지 않는다 — DEVCONTAINER_FRESHNESS=1 일 때만
# (.github/workflows/template-freshness.yml 주간 실행). 그때는 네트워크 실패도 skip 이 아니라 실패다.

load helpers

DC_DIR="$REPO_ROOT/common/devcontainer-templates"
CI_DIR="$REPO_ROOT/common/ci-templates"
MAX_AGE_DAYS=120   # maintained tags were all rebuilt within 7 days on 2026-11-04; frozen ones were 426~522 days old

# devcontainer.json is JSONC (comments allowed), so read keys with sed rather than jq.
dc_image() {
    sed -nE 's/^[[:space:]]*"image": "([^"]+)".*/\1/p' "$DC_DIR/$1/.devcontainer/devcontainer.json"
}

# Language version from a tag like mcr.microsoft.com/devcontainers/go:2-1.26-bookworm -> 1.26
dc_lang_version() {
    dc_image "$1" | sed -nE 's/.*:[0-9]+-([0-9.]+)-[a-z]+$/\1/p'
}

ci_env() {
    yq -r ".env.$2" "$CI_DIR/$1"
}

@test "devcontainer: 언어 버전이 CI 템플릿과 같다 (go·kotlin·python·typescript + python 의 node feature)" {
    local mismatch="" node_feature
    [ "$(dc_lang_version go)" = "$(ci_env ci-go.yml GO_VERSION)" ] || mismatch="$mismatch go:$(dc_lang_version go)≠$(ci_env ci-go.yml GO_VERSION)"
    [ "$(dc_lang_version kotlin)" = "$(ci_env ci-kotlin.yml JAVA_VERSION)" ] || mismatch="$mismatch kotlin:$(dc_lang_version kotlin)≠$(ci_env ci-kotlin.yml JAVA_VERSION)"
    [ "$(dc_lang_version python)" = "$(ci_env ci-python.yml PYTHON_VERSION)" ] || mismatch="$mismatch python:$(dc_lang_version python)≠$(ci_env ci-python.yml PYTHON_VERSION)"
    [ "$(dc_lang_version typescript)" = "$(ci_env ci-typescript.yml NODE_VERSION)" ] || mismatch="$mismatch typescript:$(dc_lang_version typescript)≠$(ci_env ci-typescript.yml NODE_VERSION)"
    node_feature="$(sed -nE '/features\/node:1/,/}/s/^[[:space:]]*"version": "([^"]+)".*/\1/p' "$DC_DIR/python/.devcontainer/devcontainer.json")"
    [ "$node_feature" = "$(ci_env ci-typescript.yml NODE_VERSION)" ] || mismatch="$mismatch python-node-feature:$node_feature≠$(ci_env ci-typescript.yml NODE_VERSION)"
    [ -z "$mismatch" ] || { echo "mismatch:$mismatch"; return 1; }
}

mcr_curl() {
    curl -fsSL --max-time 20 --retry 3 --retry-all-errors "$@"
}

# Build time (epoch seconds) of the linux/amd64 image behind a tag, from the public MCR registry API.
# Every step fails loudly: a missing manifest, platform, config digest or created field returns non-zero.
mcr_created_epoch() {
    local repo="$1" tag="$2" reg="https://mcr.microsoft.com/v2/devcontainers" m digest cfg blob
    local accept='application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json'
    m="$(mcr_curl -H "Accept: $accept" "$reg/$repo/manifests/$tag")" || return 1
    if jq -e 'has("manifests")' <<< "$m" >/dev/null; then
        digest="$(jq -er 'first(.manifests[] | select(.platform.architecture=="amd64" and .platform.os=="linux") | .digest)' <<< "$m")" || return 1
        m="$(mcr_curl -H "Accept: $accept" "$reg/$repo/manifests/$digest")" || return 1
    fi
    cfg="$(jq -er '.config.digest' <<< "$m")" || return 1
    blob="$(mcr_curl "$reg/$repo/blobs/$cfg")" || return 1
    # portable (no GNU date -d): strip fractional seconds, then let jq parse ISO-8601
    jq -er '.created | sub("\\.[0-9]+"; "") | fromdateiso8601' <<< "$blob"
}

@test "devcontainer: 이미지 태그가 최근 ${MAX_AGE_DAYS}일 안에 빌드된 계열을 가리킨다 (DEVCONTAINER_FRESHNESS=1 일 때만)" {
    [ "${DEVCONTAINER_FRESHNESS:-0}" = "1" ] || skip "DEVCONTAINER_FRESHNESS=1 일 때만 (주간 워크플로)"
    mcr_curl -o /dev/null "https://mcr.microsoft.com/v2/" || { echo "MCR registry unreachable"; return 1; }
    local lang image repo tag created age stale="" now
    now="$(date -u +%s)"
    for lang in go kotlin python rust typescript; do
        image="$(dc_image "$lang")"
        repo="${image#mcr.microsoft.com/devcontainers/}"; tag="${repo##*:}"; repo="${repo%%:*}"
        created="$(mcr_created_epoch "$repo" "$tag")" || { stale="$stale $lang:$image(lookup failed)"; continue; }
        age=$(( (now - created) / 86400 ))
        [ "$age" -le "$MAX_AGE_DAYS" ] || stale="$stale $lang:$image(${age}d)"
    done
    [ -z "$stale" ] || { echo "stale or missing:$stale"; return 1; }
}
