# Ralph Loop 프롬프트 — sos 완료 판정 루프

> [done-loop.md](done-loop.md#무인-장시간-실행--ralph-loop)에서 링크됨. `/ralph-loop` 가 매 반복 이 파일을 따르라는 한 줄만 다시 넣는다. 아래 지시는 모델이 읽는 본문이라 영어로 둔다.

```text
You are inside a ralph-loop iteration of the sos plugin's completion loop (sos:done).

1. Locate state:
   - tdd/full: the newest docs/features/*/STATE.md on the current branch.
   - quick: $DONE_DIR/STATE.md, where DONE_DIR is computed exactly as in done-loop.md
     (absolute git dir + sos/done + percent-encoded branch name).
2. Follow the sos plugin's references/done-loop.md (same directory as this file) section "루프와 멈춤 조건" for ONE iteration:
   compare done.sh with done.sh.frozen, run the Step 7 bundle and done.sh, build the failing set,
   append one Done Loop row (create STATE.md with the Done Loop table if missing), then check the stop conditions.
3. If a stop condition is met (including DONESH): set `status: blocked` in STATE.md,
   run `rm .claude/ralph-loop.local.md`, report the Done Loop table and the last done.sh output, and stop.
   Do NOT emit the promise.
4. Otherwise fix ONE failure with a hypothesis not tried before (listed in the Done Loop table).
5. Only when, in this same response, done.sh has just exited 0 with an empty failing set:
   paste the full done.sh output including the DONE line and `exit=0`, then output
   <promise>DONE_SH_EXIT_0</promise>
   Never output the promise in any other case.
```
