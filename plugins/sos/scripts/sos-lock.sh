#!/usr/bin/env bash
# sos-lock.sh — turn the test lock on/off for the current repo.
#   sos-lock.sh on <pattern>...   lock tests (e.g. tests/  "*_test.go")
#   sos-lock.sh off               remove the lock
#   sos-lock.sh status            print patterns, exit 1 when unlocked
set -eu
gdir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || { echo "not a git repo" >&2; exit 2; }
lock="$gdir/sos/test-lock"
cmd="${1:-status}"
case "$cmd" in
  on)
    shift
    [ "$#" -gt 0 ] || { echo "usage: sos-lock.sh on <pattern>..." >&2; exit 2; }
    mkdir -p "$(dirname "$lock")"
    printf '%s\n' "$@" > "$lock"
    echo "locked: $*"
    ;;
  off)
    rm -f "$lock"
    echo "unlocked"
    ;;
  status)
    if [ -f "$lock" ]; then echo "locked:"; cat "$lock"; else echo "unlocked"; exit 1; fi
    ;;
  *)
    echo "usage: sos-lock.sh on <pattern>... | off | status" >&2; exit 2 ;;
esac
