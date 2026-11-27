#!/usr/bin/env bats
# tests/claims.bats — 문서가 말하는 것과 장부·테스트가 어긋나지 않게 한다 (로드맵 1단계 A2 · A3).
# 이 파일은 "문서 일관성 검사"다 — 실제로 막는지는 tests/enforcement.bats 가 실행 결과로 본다(로드맵 §0.2).

load helpers

THRESHOLDS="$REPO_ROOT/common/quality-thresholds.yaml"
CLAIMS="$REPO_ROOT/common/enforcement.yaml"
# documents that quote the quality numbers
DOCS=(README.md CLAUDE.md AGENTS.md common/rules common/templates/PR_TEMPLATE.md)

# How many quotes of each metric these documents hold today. A quote that is reworded out of the phrasing
# list (or deleted) drops the count and fails — a per-metric guard, not one "at least N" for everything.
# Update these numbers deliberately when a document legitimately gains or loses a quote.
declare -gA QUOTE_COUNT=([complexity]=13 [function_lines]=14 [file_lines]=11 [coverage]=9)

setup() {
    require_tool yq
}

threshold() {
    yq -r ".thresholds.$1" "$THRESHOLDS"
}

# The number a document should quote: the standard, or a language's recorded deviation (`limit`) for
# that language's own rule file common/rules/<lang>.md.
expected() { # metric file
    local lang=""
    case "$2" in common/rules/*.md) lang="$(basename "$2" .md)" ;; esac
    LANG_KEY="$lang" M="$1" yq -r '.languages[strenv(LANG_KEY)][strenv(M)].limit // .thresholds[strenv(M)]' "$THRESHOLDS"
}

# Prints "file:line:number" for every quote of one metric, using the phrasings these documents use
# (prose, "Key: <=N" lists and markdown tables).
quotes() { # metric
    local re
    case "$1" in
        complexity)     re='([Cc]yclomatic|McCabe) complexity: ?<= ?[0-9]+|^- Complexity: ?<= ?[0-9]+|복잡도 ≤ ?[0-9]+|\| (순환 )?복잡도 \| (≤ ?)?[0-9]+' ;;
        function_lines) re='(Function|Method) length: ?<= ?[0-9]+|functions under [0-9]+ lines|\| (함수|메서드) 길이 \| (≤ ?)?[0-9]+줄|함수 ≤ ?[0-9]+줄|함수는 가능하면 [0-9]+줄' ;;
        file_lines)     re='File (size|length): ?<= ?[0-9]+|files under [0-9]+ lines|\| 파일 (길이|크기) \| (≤ ?)?[0-9]+줄|파일 ≤ ?[0-9]+줄|파일은 가능하면 [0-9]+줄' ;;
        coverage)       re='Coverage: ?>= ?[0-9]+%|커버리지 ≥ ?[0-9]+%|\| (테스트 )?커버리지 \| (≥ ?)?[0-9]+%|at least [0-9]+% meaningful coverage|Minimum [0-9]+% line coverage|커버리지를 측정하고 [0-9]+%|[0-9]+% 커버리지|^\| Unit \|.*\| [0-9]+%\+ \|' ;;
    esac
    (cd "$REPO_ROOT" && git grep -noE "$re" -- "${DOCS[@]}") | sed -E 's/^([^:]+:[0-9]+):(.*[^0-9])?([0-9]+)[^0-9]*$/\1:\3/'
}

@test "docs: 규칙·안내 문서의 품질 수치(복잡도·함수·파일·커버리지)가 정본 common/quality-thresholds.yaml 과 같다" {
    local m want q n line bad=""
    for m in complexity function_lines file_lines coverage; do
        q="$(quotes "$m")"
        n="$(grep -c . <<< "$q")"
        [ "$n" -eq "${QUOTE_COUNT[$m]}" ] || { echo "$m: $n quotes found, expected ${QUOTE_COUNT[$m]} — a quote was reworded, removed or added:"; echo "$q"; return 1; }
        bad="$bad$(while IFS= read -r line; do
            want="$(expected "$m" "${line%%:*}")"
            [ "${line##*:}" = "$want" ] || printf ' %s≠%s:%s' "$m" "$want" "$line"
        done <<< "$q")"
    done
    [ -z "$bad" ] || { echo "documents disagree with the ledger:$bad"; return 1; }
}

# Every "enforce" sentence in the rules shipped to projects must be classified in common/enforcement.yaml:
#   test: <bats test name> — this repo's templates block it (the test must exist)
#   advisory: <why> — an instruction to the project; nothing here can block it
# The match is on the whole list item (leading "- " and surrounding spaces removed), not a substring:
# a new sentence appended to a classified line must not hide behind the old entry.
enforce_items() {
    # POSIX classes, not \b: git grep -E uses the platform regex library, and macOS's has no \b (0 matches).
    # perl, not sed: BSD sed writes a literal "t" for \t in the replacement.
    (cd "$REPO_ROOT" && git grep -nEi '(^|[^[:alnum:]_])enforc(e|es|ed)([^[:alnum:]_]|$)' -- common/rules/) \
        | perl -ne 'chomp; s/^([^:]+):[0-9]+:[[:space:]]*([-*][[:space:]]+)?/$1\t/; s/[[:space:]]+$//; print "$_\n"'
}

@test "claims: 규칙의 enforce 문장이 모두 장부(common/enforcement.yaml)에 줄 전체 그대로 분류돼 있다" {
    local file text missing="" n=0
    while IFS=$'\t' read -r file text; do
        n=$(( n + 1 ))
        FILE="$file" TEXT="$text" yq -e '.claims[] | select(.file == strenv(FILE) and .text == strenv(TEXT))' "$CLAIMS" >/dev/null 2>&1 \
            || missing="$missing
  $file: $text"
    done < <(enforce_items)
    [ "$n" -ge 1 ] || { echo "no enforce sentences found — the search is broken"; return 1; }
    [ -z "$missing" ] || { echo "unclassified enforce sentences (or the ledger text differs from the rule line):$missing"; return 1; }
}

@test "claims: 장부의 각 항목은 비어 있지 않은 file·text 와, test(실재하는 bats 테스트) 또는 advisory(사유) 중 정확히 하나다" {
    local bad name
    run yq -e '.claims | length > 0' "$CLAIMS"
    [ "$status" -eq 0 ] || { echo "no claims in the ledger"; return 1; }
    # exactly one of test/advisory, and every used value is a non-blank string
    bad="$(yq -r '.claims[]
        | select(
            ((has("test")) == (has("advisory")))
            or ((.file // "") | tostring | test("^\\s*$"))
            or ((.text // "") | tostring | test("^\\s*$"))
            or (has("test") and ((.test // "") | tostring | test("^\\s*$|^null$")))
            or (has("advisory") and ((.advisory // "") | tostring | test("^\\s*$|^null$"))))
        | (.file // "?") + ": " + ((.text // "?") | tostring)' "$CLAIMS")"
    [ -z "$bad" ] || { echo "need non-empty file/text and exactly one non-empty test/advisory:"; echo "$bad"; return 1; }
    while IFS= read -r name; do
        grep -qF "@test \"$name\"" "$PROJECT_ROOT"/tests/*.bats || bad="$bad [$name]"
    done < <(yq -r '.claims[] | select(has("test")) | .test' "$CLAIMS")
    [ -z "$bad" ] || { echo "claims point at tests that do not exist:$bad"; return 1; }
    # an entry whose exact line is gone from the rule file is stale
    bad="$(enforce_items | sort -u > "$BATS_TEST_TMPDIR/items"
        # the tab comes from the environment: "\t" in a yq string literal is backslash-t in yq 4.47.1, a tab in 4.52.4
        TAB=$'\t' yq -r '.claims[] | .file + strenv(TAB) + .text' "$CLAIMS" | while IFS= read -r entry; do
            grep -qxF -- "$entry" "$BATS_TEST_TMPDIR/items" || printf ' [%s]' "$entry"
        done)"
    [ -z "$bad" ] || { echo "stale ledger entries (rule line changed or removed):$bad"; return 1; }
}

@test "adr: ADR 복사용 템플릿 블록에 Enforced by 칸과 test · advisory 작성 지침이 있다" {
    local block
    # only the fenced block under "## 템플릿" — the example further down has its own Enforced by section
    block="$(awk '/^## 템플릿/{in_t=1; next} /^## 예시/{in_t=0} in_t' "$REPO_ROOT/common/templates/ADR_TEMPLATE.md")"
    grep -q '^## Enforced by' <<< "$block" || { echo "template block has no '## Enforced by'"; return 1; }
    grep -qi 'advisory' <<< "$block" || { echo "template block does not explain advisory"; return 1; }
}
