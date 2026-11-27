#!/usr/bin/env bash
# Shared helpers for ShipOrSink shell tests.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034  # read by the test scripts that source this file
PLUGIN="$ROOT/plugins/sos"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL $1"; }

# expect <name> <expected-exit> <actual-exit>
expect() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi
}

# mk_repo: create an isolated git repo under a fresh temp dir and print its path
mk_repo() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/sos-test.XXXXXX")" || { echo "mktemp failed" >&2; exit 99; }
  [ -n "$d" ] && [ -d "$d" ] || { echo "empty temp dir" >&2; exit 99; }
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name tester
  git -C "$d" config commit.gpgsign false
  echo "$d"
}

summary() {
  echo "PASS=$PASS FAIL=$FAIL"
  [ "$FAIL" -eq 0 ]
}
