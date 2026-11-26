#!/usr/bin/env bash
# coverage-gate.sh — the coverage quality gate (dev-standards common/quality-thresholds.yaml, roadmap stage 3 A7):
#   1. changed lines: diff-cover — the lines this branch changed must be >= --fail-under % covered (default 80)
#   2. ratchet: the total line coverage must not drop below the number in --baseline (default .coverage-baseline)
# Copied into projects as scripts/coverage-gate.sh by the language bootstraps and called after the coverage report is
# written: by the pre-push hook `coverage-gate` (rust · java-spring · kotlin-spring · swift · csharp-dotnet · flutter-dart ·
# ruby-rails) or by the CI step "Coverage gate" on pull requests (common/ci-templates/ci-python · ci-go · ci-typescript).
#
# Usage: scripts/coverage-gate.sh <report> [<report> …] [--compare-branch origin/main] [--fail-under 80]
#                                          [--baseline .coverage-baseline] [--write-baseline] [--src-roots "a b"]
#   <report>          lcov (*.info) · JaCoCo XML · Cobertura XML — several (one per test project) are merged
#   --write-baseline  record the current total in the baseline file and stop (a person runs it, then commits the file)
#   --src-roots       JaCoCo source roots, space separated (default: src/main/java src/main/kotlin src/test/java
#                     src/test/kotlin — diff-cover's own default is Java only, so Kotlin sources would not match)
# Fails when: the report is missing · the compare branch does not exist · the changed lines are below --fail-under ·
#   a report names source files of which none exists in the repository (paths do not match — diff-cover itself exits 0
#   then; checked per report, so one good report does not hide a mismatched one) ·
#   the total dropped below the baseline · the baseline file is not a number in 0..100.
# A missing baseline file skips the ratchet with a notice (first adoption). A change the report does not measure at all
# (docs, tests, files outside the report) passes the changed-line check with a notice.
# Needs: git, python3, and uv (`uvx`) or pipx — diff-cover runs at the pinned version below, never `latest`.
set -euo pipefail

# renovate: datasource=pypi depName=diff-cover
DIFF_COVER_VERSION="11.0.0"

reports=()
compare="origin/main"
fail_under=80
baseline=".coverage-baseline"
write=0
src_roots="src/main/java src/main/kotlin src/test/java src/test/kotlin"
while [ $# -gt 0 ]; do
    case "$1" in
        --compare-branch) compare="$2"; shift 2 ;;
        --fail-under) fail_under="$2"; shift 2 ;;
        --baseline) baseline="$2"; shift 2 ;;
        --write-baseline) write=1; shift ;;
        --src-roots) src_roots="$2"; shift 2 ;;
        -*) echo "coverage-gate: unknown option: $1" >&2; exit 2 ;;
        *) reports+=("$1"); shift ;;
    esac
done
[ "${#reports[@]}" -gt 0 ] || { echo "FAIL: no coverage report given — usage: coverage-gate.sh <report> [<report> …] [options]" >&2; exit 1; }
for report in "${reports[@]}"; do
    [ -f "$report" ] || { echo "FAIL: coverage report not found: $report" >&2; exit 1; }
done

# Prints the total line coverage of all reports merged on the first line (a line counts once, hit when any report hit
# it; two decimals, "nan" when no line is instrumented), then every report that names source files of which none exists
# in the repository (its paths do not match — a report with no source file at all is not listed).
measured="$(python3 -I - "$src_roots" "${reports[@]}" <<'PY'
import os
import sys
import xml.etree.ElementTree as ET

roots = sys.argv[1].split()
lines = {}  # file -> {line number: hit}
named = resolved = 0  # source files named / found in the repository, per report


def local(path):
    """Repository-relative path when it names a file under the current directory, else None."""
    p = os.path.relpath(path) if os.path.isabs(path) else os.path.normpath(path)
    return p if not p.startswith("..") and os.path.isfile(p) else None


def source_file(candidates, fallback):
    global named, resolved
    found = next((p for p in map(local, candidates) if p), None)
    named += 1
    resolved += found is not None
    # an unresolved file is keyed by its report too, so same-named files of two reports never share line numbers
    return lines.setdefault(found or f"{report}::{fallback}", {})


def add(entry, number, hit):
    entry[number] = entry.get(number, False) or hit


unmatched = []
for report in sys.argv[2:]:
    named = resolved = 0
    text = open(report, encoding="utf-8").read()
    if text.lstrip().startswith("<"):
        root = ET.fromstring(text)
        if root.tag == "report":  # JaCoCo: package/sourcefile under one of the source roots
            for pkg in root.iter("package"):
                for sf in pkg.findall("sourcefile"):
                    rel = "/".join(p for p in (pkg.get("name", ""), sf.get("name")) if p)
                    entry = source_file([os.path.join(r, rel) for r in roots], rel)
                    for ln in sf.findall("line"):
                        add(entry, int(ln.get("nr")), int(ln.get("ci", "0")) > 0)
        else:  # Cobertura: filename alone or under one of <sources>
            sources = [s.text.strip() for s in root.iter("source") if s.text and s.text.strip()]
            for cls in root.iter("class"):
                name = cls.get("filename")
                entry = source_file([name] + [os.path.join(s, name) for s in sources], name)
                for ln in cls.iter("line"):
                    add(entry, int(ln.get("number")), int(ln.get("hits", "0")) > 0)
    else:  # lcov
        entry = None
        for line in text.splitlines():
            if line.startswith("SF:"):
                entry = source_file([line[3:].strip()], line[3:].strip())
            elif line.startswith("DA:") and entry is not None:
                number, hits = line[3:].split(",")[:2]
                add(entry, int(number), int(hits) > 0)
            elif line == "end_of_record":
                entry = None

    if named and not resolved:
        unmatched.append(report)

found = sum(len(e) for e in lines.values())
hit = sum(sum(e.values()) for e in lines.values())
print("nan" if found == 0 else f"{hit * 100 / found:.2f}")
for report in unmatched:
    print(report)
PY
)"
total="${measured%%$'\n'*}"
unmatched="${measured#"$total"}"; unmatched="${unmatched#$'\n'}"

if [ "$write" = 1 ]; then
    [ "$total" != "nan" ] || { echo "FAIL: the report has no instrumented line — nothing to record" >&2; exit 1; }
    echo "$total" > "$baseline"
    echo "coverage-gate: wrote $baseline = $total% (commit it)"
    exit 0
fi

if command -v uvx >/dev/null 2>&1; then
    diff_cover=(uvx "diff-cover@${DIFF_COVER_VERSION}")
elif command -v pipx >/dev/null 2>&1; then
    diff_cover=(pipx run --spec "diff-cover==${DIFF_COVER_VERSION}" diff-cover)
else
    echo "FAIL: coverage-gate needs uv (uvx) or pipx to run diff-cover ${DIFF_COVER_VERSION}" >&2
    exit 1
fi

git rev-parse --verify -q "${compare}^{commit}" >/dev/null \
    || { echo "FAIL: compare branch not found: $compare (fetch it, or pass --compare-branch)"; exit 1; }

failed=0
while IFS= read -r r; do
    [ -n "$r" ] || continue
    echo "FAIL: no file of $r exists in the repository — report paths do not match (check --src-roots / the report)"
    failed=1
done <<< "$unmatched"
read -r -a roots <<< "$src_roots"
rc=0
dc_out="$("${diff_cover[@]}" "${reports[@]}" --compare-branch="$compare" --fail-under="$fail_under" --src-roots "${roots[@]}" 2>&1)" || rc=$?
printf '%s\n' "$dc_out"
if grep -qF 'No lines with coverage information' <<< "$dc_out"; then
    [ -n "$unmatched" ] \
        || echo "coverage-gate: the report measures none of the changed lines (docs, tests or files outside the report only) — changed-line check passes"
elif [ "$rc" -ne 0 ]; then
    echo "FAIL: changed-line coverage is below ${fail_under}% (against ${compare})"
    failed=1
fi

base_value=""
[ ! -f "$baseline" ] || base_value="$(tr -d '[:space:]' < "$baseline")"
if [ -f "$baseline" ] && ! python3 -I -c 'import sys, re; v = sys.argv[1]; sys.exit(0 if re.fullmatch(r"[0-9]+(\.[0-9]+)?", v) and 0 <= float(v) <= 100 else 1)' "$base_value"; then
    echo "FAIL: invalid baseline in $baseline: [$base_value] — expected a number 0..100 (rewrite it with --write-baseline)"
    failed=1
elif [ ! -f "$baseline" ]; then
    echo "coverage-gate: no $baseline — total-coverage ratchet skipped (record one with --write-baseline)"
elif [ "$total" = "nan" ]; then
    echo "FAIL: the report has no instrumented line"
    failed=1
elif python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)' "$total" "$base_value"; then
    echo "coverage-gate: total $total% >= baseline $base_value%"
else
    echo "FAIL: total coverage $total% dropped below the baseline $base_value% ($baseline)"
    failed=1
fi
exit "$failed"
