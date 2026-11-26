#!/usr/bin/env bash
# H2: the test-lock hook blocks test edits while locked, unless a human-approved ledger row exists.
. "$(dirname "$0")/_lib.sh"
HOOK="$PLUGIN/hooks/test-lock.py"
[ -f "$HOOK" ] || { echo "  FAIL $HOOK missing: $HOOK"; echo "PASS=0 FAIL=1"; exit 1; }

R="$(mk_repo)"
mkdir -p "$R/tests" "$R/src" "$R/docs"
echo 'def test_a(): assert 1 == 1' > "$R/tests/test_auth.py"
echo 'x = 1' > "$R/src/app.py"
LEDGER_HEAD='| test_id | file | ac_old | ac_new | action | reason | classification | approved_by | approved_at | commit | replacement |
|---|---|---|---|---|---|---|---|---|---|---|'
printf '%s\n' "$LEDGER_HEAD" > "$R/docs/TEST-LEDGER.md"
git -C "$R" add -A && git -C "$R" commit -qm init

run_hook() {  # run_hook <json> -> exit code
  printf '%s' "$1" | python3 "$HOOK" >/dev/null 2>&1
  echo $?
}
edit_json() {  # edit_json <tool> <abs path>
  printf '{"tool_name":"%s","cwd":"%s","tool_input":{"file_path":"%s","old_string":"1 == 1","new_string":"True"}}' "$1" "$R" "$2"
}
bash_json() { printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$R" "$1"; }

echo "T1 no lock -> test edit allowed"
expect "edit allowed without lock" 0 "$(run_hook "$(edit_json Edit "$R/tests/test_auth.py")")"

GITDIR="$(git -C "$R" rev-parse --absolute-git-dir)"
mkdir -p "$GITDIR/sos" && echo 'tests/' > "$GITDIR/sos/test-lock"

echo "T2 locked -> test edit blocked"
expect "Edit on locked test blocked" 2 "$(run_hook "$(edit_json Edit "$R/tests/test_auth.py")")"
expect "Write on locked test blocked" 2 "$(run_hook "$(edit_json Write "$R/tests/test_auth.py")")"
expect "new file under locked dir blocked" 2 "$(run_hook "$(edit_json Write "$R/tests/test_new.py")")"

echo "T3 locked -> source edit allowed"
expect "Edit on source allowed" 0 "$(run_hook "$(edit_json Edit "$R/src/app.py")")"

echo "T4 Bash mutation of locked test blocked, read allowed"
expect "rm locked test blocked" 2 "$(run_hook "$(bash_json "rm tests/test_auth.py")")"
expect "sed -i locked test blocked" 2 "$(run_hook "$(bash_json "sed -i s/1/2/ tests/test_auth.py")")"
expect "redirect into locked test blocked" 2 "$(run_hook "$(bash_json "echo x > tests/test_auth.py")")"
expect "cat locked test allowed" 0 "$(run_hook "$(bash_json "cat tests/test_auth.py")")"
expect "pytest run allowed" 0 "$(run_hook "$(bash_json "pytest -q tests/test_auth.py")")"

echo "T5 model cannot fill approval columns"
NEW_ROW='| TC-001-1 | tests/test_auth.py | AC-001 | AC-004 | rewrite | spec change | INTENDED | me | 2026-11-26 | abc | TC-004-1 |'
WJ="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","cwd":sys.argv[1],"tool_input":{"file_path":sys.argv[1]+"/docs/TEST-LEDGER.md","content":sys.argv[2]+"\n"+sys.argv[3]+"\n"}}))' "$R" "$LEDGER_HEAD" "$NEW_ROW")"
expect "Write adding approved row blocked" 2 "$(run_hook "$WJ")"
PENDING='| TC-001-1 | tests/test_auth.py | AC-001 | AC-004 | rewrite | spec change | INTENDED |  |  |  | TC-004-1 |'
WJ2="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","cwd":sys.argv[1],"tool_input":{"file_path":sys.argv[1]+"/docs/TEST-LEDGER.md","content":sys.argv[2]+"\n"+sys.argv[3]+"\n"}}))' "$R" "$LEDGER_HEAD" "$PENDING")"
expect "Write adding pending row allowed" 0 "$(run_hook "$WJ2")"
expect "bash edit of ledger blocked" 2 "$(run_hook "$(bash_json "sed -i s/x/y/ docs/TEST-LEDGER.md")")"

echo "T6 pending row does not unlock"
printf '%s\n%s\n' "$LEDGER_HEAD" "$PENDING" > "$R/docs/TEST-LEDGER.md"
expect "pending row keeps lock" 2 "$(run_hook "$(edit_json Edit "$R/tests/test_auth.py")")"

echo "T7 human-approved row unlocks that file only"
printf '%s\n%s\n' "$LEDGER_HEAD" "$NEW_ROW" > "$R/docs/TEST-LEDGER.md"
expect "approved file editable" 0 "$(run_hook "$(edit_json Edit "$R/tests/test_auth.py")")"
expect "other locked file still blocked" 2 "$(run_hook "$(edit_json Write "$R/tests/test_new.py")")"

echo "T8 malformed input"
printf 'not json' | python3 "$HOOK" >/dev/null 2>&1
expect "garbage stdin passes (no repo to check)" 0 "$?"

rm -rf "$R"
summary
