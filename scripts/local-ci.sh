#!/usr/bin/env bash
# Run the jobs of .github/workflows/ci.yml locally with the versions pinned there (bats is run separately).
# Usage: local-ci.sh <repo root> <log dir>
# Prints one "<job> PASS|FAIL" line per job; full output per job goes to <log dir>/<job>.log.
set -uo pipefail
ROOT="${1:?repo root}"
LOG="${2:?log dir}"
mkdir -p "$LOG"
cd "$ROOT" || exit 2

pin() { sed -nE "s/^  $1: \"([^\"]+)\".*/\1/p" .github/workflows/ci.yml; }
RUFF_VERSION="$(pin RUFF_VERSION)"
MYPY_VERSION="$(pin MYPY_VERSION)"
ZIZMOR_VERSION="$(pin ZIZMOR_VERSION)"
MARKDOWNLINT_CLI2_VERSION="$(pin MARKDOWNLINT_CLI2_VERSION)"
RENOVATE_VERSION="$(pin RENOVATE_VERSION)"
ACTIONLINT_VERSION="$(pin ACTIONLINT_VERSION)"

job() { # name, then the command as a function
    local name="$1"; shift
    if "$@" > "$LOG/$name.log" 2>&1; then echo "$name PASS"; else echo "$name FAIL (exit $?)"; fi
}

j_shellcheck() {
    shellcheck --version | head -2
    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.sh' '*.bats' 'tests/*.bash')
    shellcheck -x "${files[@]}"
}

j_actionlint() {
    [ "$(actionlint -version | head -1)" = "$ACTIONLINT_VERSION" ] || { echo "actionlint is not $ACTIONLINT_VERSION"; return 1; }
    actionlint -shellcheck= \
        plugins/sos/standards/common/ci-templates/*.yml \
        plugins/sos/standards/common/security-templates/*-ci.yml \
        plugins/sos/standards/common/security-templates/security-review.yml \
        plugins/sos/standards/common/github-templates/workflows/*.yml \
        .github/workflows/*.yml
}

j_python() {
    local targets=(plugins/sos/standards/common/hooks/hooklib.py)
    uvx "ruff==$RUFF_VERSION" check "${targets[@]}" &&
        uvx "ruff==$RUFF_VERSION" format --check "${targets[@]}" &&
        uvx "mypy==$MYPY_VERSION" --strict --python-version 3.12 "${targets[@]}"
}

j_zizmor() {
    uvx "zizmor==$ZIZMOR_VERSION" --version
    uvx "zizmor==$ZIZMOR_VERSION" --no-online-audits --strict-collection --no-config --no-ignores \
        plugins/sos/standards/common/ci-templates/*.yml \
        plugins/sos/standards/common/security-templates/*.yml \
        plugins/sos/standards/common/github-templates/workflows/*.yml
}

j_renovate_config() {
    docker run --rm -v "$PWD:/repo:ro" -w /repo "ghcr.io/renovatebot/renovate:${RENOVATE_VERSION}" renovate-config-validator --strict || return 1
    local out report ann bad=0 want got f
    out="$(mktemp -d)"; chmod 777 "$out"
    docker run --rm -v "$PWD:/repo:ro" -v "$out:/out" -w /repo \
        -e LOG_LEVEL=warn -e RENOVATE_REPORT_TYPE=file -e RENOVATE_REPORT_PATH=/out/report.json \
        "ghcr.io/renovatebot/renovate:${RENOVATE_VERSION}" \
        sh -c 'git config --global --add safe.directory /repo && renovate --platform=local --dry-run=extract' || return 1
    report="$out/report.json"
    ann='^[[:space:]]*(#|//) renovate: datasource='
    while IFS= read -r f; do
        if [ "$f" = plugins/sos/standards/typescript-react/templates/dev-dependencies.txt ]; then
            want="$(grep -cvE '^#|^$' "$f" || true)"
        else
            want="$(grep -cE "$ann" "$f" || true)"
        fi
        got="$(jq -r --arg f "$f" '[.repositories.local.packageFiles.regex[]? | select(.packageFile == $f) | .deps[]] | length' "$report")"
        echo "$f annotations=$want extracted=$got"
        [ "$got" = "$want" ] || { echo "MISMATCH $f: $want pins but Renovate extracted $got"; bad=1; }
    done < <(git grep -lE "$ann" -- . ':!docs' ':!tests' ':!*.md'; echo plugins/sos/standards/typescript-react/templates/dev-dependencies.txt)
    return "$bad"
}

j_markdownlint() {
    npx --yes "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}" "**/*.md"
}

j_apply_dry_run() {
    local level target
    for level in slim standard full enterprise; do
        target="$(mktemp -d)"
        echo "== level $level"
        bash plugins/sos/standards/apply.sh --level "$level" --dry-run --target "$target" || { echo "apply-dry-run $level failed"; return 1; }
    done
}

echo "repo $(git rev-parse --short HEAD) ($(git branch --show-current))"
job shellcheck j_shellcheck
job actionlint j_actionlint
job python j_python
job zizmor j_zizmor
job renovate-config j_renovate_config
job markdownlint j_markdownlint
job apply-dry-run j_apply_dry_run
