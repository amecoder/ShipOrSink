#!/usr/bin/env bash
# H3: sos:setup's pre-approval steps (--check, --dry-run) write nothing to the target repo.
# shellcheck source=SCRIPTDIR/_lib.sh
. "$(dirname "$0")/_lib.sh"
APPLY="$PLUGIN/standards/apply.sh"
[ -f "$APPLY" ] || { echo "  FAIL apply.sh missing"; echo "PASS=0 FAIL=1"; exit 1; }

R="$(mk_repo)"
printf '[project]\nname = "demo"\nversion = "0.1.0"\n' > "$R/pyproject.toml"
git -C "$R" add -A && git -C "$R" commit -qm init
snapshot() { (cd "$R" && find . -path ./.git -prune -o -print | LC_ALL=C sort | xargs -I{} sh -c 'if [ -f "{}" ]; then shasum "{}"; else echo "{}"; fi'); }
before="$(snapshot)"

echo "S1 --check on a fresh repo reports, writes nothing"
bash "$APPLY" --check --target "$R" </dev/null >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] && ok "--check exit non-zero without manifest (rc=$rc)" || bad "--check exit 0 on fresh repo"
[ "$(snapshot)" = "$before" ] && ok "--check wrote nothing" || bad "--check changed files"

echo "S2 --dry-run for each level writes nothing"
for level in slim standard; do
  out="$(bash "$APPLY" --dry-run --yes --level "$level" --lang python --target "$R" </dev/null 2>&1)"
  rc=$?
  [ "$rc" -eq 0 ] && ok "dry-run $level exit 0" || bad "dry-run $level exit $rc: $(printf '%s' "$out" | tail -3)"
  [ "$(snapshot)" = "$before" ] && ok "dry-run $level wrote nothing" || bad "dry-run $level changed files"
done

echo "S3 real apply (after approval) does write"
bash "$APPLY" --yes --level slim --lang python --target "$R" </dev/null >/dev/null 2>&1
[ "$(snapshot)" != "$before" ] && ok "apply wrote files" || bad "apply wrote nothing"
bash "$APPLY" --check --target "$R" </dev/null >/dev/null 2>&1
expect "--check exit 0 right after apply" 0 "$?"

rm -rf "$R"
summary
