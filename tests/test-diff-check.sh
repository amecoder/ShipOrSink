#!/usr/bin/env bash
# H4: the ship-time diff check rejects test weakening that has no human-approved ledger row.
. "$(dirname "$0")/_lib.sh"
CHECK="$PLUGIN/scripts/test-diff-check.py"
[ -f "$CHECK" ] || { echo "  FAIL $CHECK missing: $CHECK"; echo "PASS=0 FAIL=1"; exit 1; }

LEDGER_HEAD='| test_id | file | ac_old | ac_new | action | reason | classification | approved_by | approved_at | commit | replacement |
|---|---|---|---|---|---|---|---|---|---|---|'

setup_repo() {
  R="$(mk_repo)"
  mkdir -p "$R/tests" "$R/src" "$R/docs"
  printf 'def test_a():\n    assert f(1) == 2\n    assert f(2) == 3\n' > "$R/tests/test_math.py"
  printf 'def test_b():\n    assert g() is None\n' > "$R/tests/test_other.py"
  echo 'x = 1' > "$R/src/app.py"
  printf '%s\n' "$LEDGER_HEAD" > "$R/docs/TEST-LEDGER.md"
  git -C "$R" add -A && git -C "$R" commit -qm base
  BASE="$(git -C "$R" rev-parse HEAD)"
}
run_check() { (cd "$R" && python3 "$CHECK" "$BASE" >/dev/null 2>&1); echo $?; }
commit_all() { git -C "$R" add -A && git -C "$R" commit -qm "$1"; }

echo "D1 source-only change passes"
setup_repo; echo 'x = 2' > "$R/src/app.py"; commit_all src
expect "source change ok" 0 "$(run_check)"; rm -rf "$R"

echo "D2 adding a test passes"
setup_repo; printf 'def test_c():\n    assert 1\n' > "$R/tests/test_new.py"; commit_all add
expect "new test ok" 0 "$(run_check)"; rm -rf "$R"

echo "D3 pytest skip marker added fails"
setup_repo; printf 'import pytest\n@pytest.mark.skip\ndef test_a():\n    assert f(1) == 2\n    assert f(2) == 3\n' > "$R/tests/test_math.py"; commit_all skip
expect "skip blocked" 1 "$(run_check)"; rm -rf "$R"

echo "D4 js it.skip added fails"
setup_repo; printf "it.skip('x', () => { expect(1).toBe(1) })\n" > "$R/tests/a.test.js"; commit_all jsskip
expect "it.skip blocked" 1 "$(run_check)"; rm -rf "$R"

echo "D5 assertion removed fails"
setup_repo; printf 'def test_a():\n    assert f(1) == 2\n' > "$R/tests/test_math.py"; commit_all weaken
expect "assert decrease blocked" 1 "$(run_check)"; rm -rf "$R"

echo "D6 test file deleted fails"
setup_repo; git -C "$R" rm -q tests/test_other.py; commit_all del
expect "delete blocked" 1 "$(run_check)"; rm -rf "$R"

echo "D7 approved ledger row allows that file"
setup_repo; git -C "$R" rm -q tests/test_other.py
printf '%s\n%s\n' "$LEDGER_HEAD" '| TC-002-1 | tests/test_other.py | AC-002 | - | delete | AC-002 removed by spec v2 | INTENDED | human | 2026-11-26 | - | - |' > "$R/docs/TEST-LEDGER.md"
commit_all approved
expect "approved delete ok" 0 "$(run_check)"; rm -rf "$R"

echo "D8 pending ledger row does not allow"
setup_repo; git -C "$R" rm -q tests/test_other.py
printf '%s\n%s\n' "$LEDGER_HEAD" '| TC-002-1 | tests/test_other.py | AC-002 | - | delete | reason | INTENDED |  |  | - | - |' > "$R/docs/TEST-LEDGER.md"
commit_all pending
expect "pending delete blocked" 1 "$(run_check)"; rm -rf "$R"

echo "D9 bad base ref is an error, not a pass"
setup_repo
(cd "$R" && python3 "$CHECK" no-such-ref >/dev/null 2>&1); expect "bad ref exit 2" 2 "$?"; rm -rf "$R"

summary
