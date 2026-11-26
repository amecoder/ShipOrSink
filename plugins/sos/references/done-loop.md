# 완료 판정 루프 — done.sh 가 통과할 때까지

> [cycle](../skills/cycle/SKILL.md)에서 링크됨. 모든 모드 공통. 완료는 모델이 체크박스에 표시해서가 아니라 **`done.sh` 의 종료 코드**로 판정한다 — 모델이 쓴 마커는 모델이 그대로 써넣을 수 있어 가장 약한 근거이고, 명령 실행 결과는 그보다 강하다. 아래의 동결은 약화를 막지 못하고 드러낼 뿐이다 — 막는 것은 사람이 diff 를 읽는 일이다.

## 목차
- [done.sh 계약](#donesh-계약)
- [예시](#예시)
- [작성 시점·기준선·동결](#작성-시점기준선동결)
- [루프와 멈춤 조건](#루프와-멈춤-조건)
- [done.sh 를 약하게 만들지 않는다](#donesh-를-약하게-만들지-않는다)
- [무인 장시간 실행 — ralph-loop](#무인-장시간-실행--ralph-loop)

---

## done.sh 계약

| 항목 | 규칙 |
|------|------|
| 위치 | `tdd`/`full`: `$FEATURE_DIR/done.sh` · `quick`: `$DONE_DIR/done.sh` (아래 스니펫 — 커밋되지 않고 세션이 끝나도 남는다) |
| 대응 | **AC 하나에 `check` 한 줄.** SPEC.md 의 AC-01.. 가 빠짐없이 있어야 한다(quick 은 시작할 때 요청에서 뽑은 AC). `EXPECTED` 에 `check` 줄 수를 적는다 |
| 출력 | AC 마다 `PASS AC-xx` · `FAIL AC-xx` · `ERROR AC-xx` 한 줄, 마지막에 `DONE <통과>/<EXPECTED>` |
| 종료 코드 | 전부 PASS 면 0, FAIL 이 있으면 1, 실행 불가(명령 없음 126·127, 저장소 밖, `check` 줄 수가 `EXPECTED` 와 다름)면 2 |
| 성질 | 저장소 루트에서 실행, 각 명령은 `</dev/null` 과 시간 제한(`LIMIT`, 넘으면 프로세스 그룹째 종료)으로 돈다. `EXPECTED × LIMIT ≤ 600` 초가 되게 고르고 Bash 도구 호출에 `timeout: 600000` 을 준다 — 더 길면 `run_in_background` 로 돌린다(도구 시간 초과로 출력이 잘리면 DONE 줄이 없어 거짓 DONESH 가 난다), 같은 코드면 같은 결과(외부 네트워크·시각 의존 금지, `uv run --frozen` 처럼 잠금 파일을 고정), 저장소 파일을 바꾸지 않는다 |
| 명령으로 못 바꾸는 AC | SPEC 승인 때 **사용자가** "수동 확인"으로 정한 것만 `echo "MANUAL AC-xx"` 로 찍고 종료 코드에서 뺀다. 완료 보고에 "사용자가 확인할 것"으로 따로 적는다. 모델이 나중에 FAIL 을 MANUAL 로 바꾸는 것은 AC 제거와 같다 |

quick 의 `DONE_DIR` 은 브랜치 이름을 그대로 폴더 이름으로 쓴다. `/` 와 `%` 만 퍼센트 인코딩해서 `feat/a-b` 와 `feat-a/b` 가 같은 폴더로 겹치지 않게 한다. 브랜치가 없는 detached HEAD 에서는 시작하지 않는다.

```bash
b=$(git branch --show-current); [ -n "$b" ] || { echo "detached HEAD: create a branch first" >&2; exit 2; }
DONE_DIR="$(git rev-parse --absolute-git-dir)/sos/done/$(printf %s "$b" | sed 's/%/%25/g; s#/#%2F#g')"
mkdir -p "$DONE_DIR"
```

STATE.md 의 AC 체크박스는 **done.sh 출력을 옮겨 적은 것**일 뿐 판정 근거가 아니다. 완료 보고에는 체크박스 대신 마지막 done.sh 출력 전문과 종료 코드를 붙이고, 사람이 직접 다시 돌려 볼 한 줄(`bash <done.sh 절대 경로>; echo "exit=$?"`)을 적는다.

## 예시

로그인 기능의 AC 다섯 개를 옮긴 예다. 넷은 명령으로 확인하고, 사람이 눈으로 봐야 하는 문구 검토 하나만 SPEC 승인 때 MANUAL 로 정했다. `/bin/bash` 3.2 와 bash 5 양쪽에서 돈다.

```bash
#!/usr/bin/env bash
# done.sh — completion check for "login-jwt". One AC = one check line.
# Frozen copy: done.sh.frozen. Any edit after freeze must be reported with a reason.
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 2
cd "$root" || exit 2
EXPECTED=4    # number of check lines below (MANUAL lines excluded)
LIMIT=120     # seconds per check; keep EXPECTED * LIMIT <= 600 (Bash tool timeout 600000 ms)
LOG_DIR="${TMPDIR:-/tmp}/done-login-jwt"; mkdir -p "$LOG_DIR" || exit 2
pass=0; fail=0; error=0

check() {  # check <AC-id> <command...>
  local id=$1 rc; shift
  # run in its own process group; on timeout kill the whole group (grandchildren too) and exit 142
  { perl -e 'my $t = shift; my $pid = fork; exit 127 unless defined $pid;
    if (!$pid) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV or exit 127 }
    $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 1; kill "KILL", -$pid; exit 142 };
    alarm $t; waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);' "$LIMIT" "$@" </dev/null >"$LOG_DIR/$id.log" 2>&1; } 2>/dev/null
  rc=$?
  case $rc in
    0)       echo "PASS $id"; pass=$((pass + 1)) ;;
    126|127) echo "ERROR $id  (rc=$rc, not runnable; log: $LOG_DIR/$id.log)"; error=$((error + 1)) ;;
    142)     echo "FAIL $id  (timeout ${LIMIT}s; log: $LOG_DIR/$id.log)"; fail=$((fail + 1)) ;;
    *)       echo "FAIL $id  (rc=$rc; log: $LOG_DIR/$id.log)"; fail=$((fail + 1)) ;;
  esac
}

check AC-01 uv run --frozen pytest -q tests/test_login.py::test_valid_credentials_return_jwt
check AC-02 uv run --frozen pytest -q tests/test_login.py::test_wrong_password_returns_401
check AC-03 uv run --frozen pytest -q tests/test_login.py::test_token_expires_after_15_min
check AC-04 bash -c 'uv run --frozen python -m app.cli login --help | grep -q -- "--dry-run"'
echo "MANUAL AC-05"   # approved by user at SPEC: login page copy reviewed by eye

echo "DONE $pass/$EXPECTED"
total=$((pass + fail + error))
[ "$total" -eq "$EXPECTED" ] || { echo "ERROR ran $total checks, EXPECTED $EXPECTED"; exit 2; }
[ "$error" -eq 0 ] || exit 2
[ "$fail" -eq 0 ]
```

## 작성 시점·기준선·동결

1. **쓴다**: `tdd`/`full` 은 Phase 1 Step 3(DESIGN) 작성 직후에 쓰고 DESIGN 승인 때 함께 보여 준다. 승인되면 `cp done.sh done.sh.approved` 로 사용자가 본 판을 남긴다. 문서만 요청한 실행(Phase 0→1 종료)이면 쓰지 않는다. `quick` 은 Step 0 끝(구현 전)에 쓴다. 둘 다 `chmod +x` 한다
2. **기준선**: 새 동작 AC 는 기준선에서 **테스트가 실패해서 FAIL** 이어야 한다. 구현 전에 PASS 하는 AC 는 아무것도 검증하지 않으니 명령을 고친다(RED 가 실패해야 하는 것과 같은 이유). FAIL 이어도 각 로그를 읽어 실패 이유를 확인한다. pytest 종료 코드 5(no tests collected)·4(파일 없음)나 `ERROR` 는 명령이 틀린 것이라 고친다. 원래 통과해야 정상인 회귀 방지 AC(예: "기존 테스트 전부 통과")만 PASS 를 허용하고 표시한다
   - `tdd`/`full`: Phase 2 Step 4 의 **RED 스냅샷 커밋 직후** 실행한 결과가 기준선이다. 그 커밋 해시를 `tests_frozen_at` 으로 남긴다
   - `tdd`/`full` + `--sdd`: 테스트는 태스크마다 서브에이전트가 만드므로 RED 커밋이 하나로 모이지 않는다. 그래서 **첫 태스크를 디스패치하기 전에** 돌린 결과를 기준선으로 삼고 "테스트가 아직 없어서 FAIL"이라고 표시한다(이때만 테스트 없음 FAIL 을 허용). 테스트 diff 기준은 파일마다 그 파일을 추가한 커밋이다 — `git log --diff-filter=A --format=%H -1 -- <테스트 파일>`
   - `quick`: Step 0 에서 실행한 결과를 `$DONE_DIR/baseline.txt` 에 남긴다(`bash done.sh | tee baseline.txt`). 테스트는 구현과 함께 생기므로, AC 를 검증하는 테스트 파일이 처음 생긴 반복이 끝날 때 `rsync -R --ignore-existing <저장소 상대 경로들> "$DONE_DIR/tests.frozen/"` 로 사본을 남긴다(이미 찍은 파일은 덮지 않는다)
3. **동결**: 기준선 직후 `cp done.sh done.sh.frozen` 한다. `tdd`/`full` 은 기준선 보고에 `diff -u done.sh.approved done.sh` 를 붙인다 — 승인 뒤 동결 전에 바뀐 것이 있으면 여기서 드러난다. `tdd`/`full` 은 STATE.md 에 아래처럼 기록한다. `quick` 은 STATE.md 를 첫 실패 반복이 나온 뒤에야 만든다(그 전에 끝나면 기록할 것이 없다)

```yaml
done:
  script: docs/features/2026-11-26_login-jwt/done.sh
  frozen: docs/features/2026-11-26_login-jwt/done.sh.frozen
  tests_frozen_at: <RED snapshot commit>   # --sdd: per file, commit that added it · quick: $DONE_DIR/tests.frozen/
  loop_iter: 0
  stall: 0
```

## 루프와 멈춤 조건

구현이 끝나면(`tdd`/`full` 은 Phase 3 Step 7 뒤, `quick` 은 Step 3 뒤) 아래를 반복한다. **`tdd`/`quick` 은 묻지 않고 계속 간다** — 멈추는 것은 아래 멈춤 조건뿐이다. `full` 은 반복마다 실패 집합과 다음 가설을 보여 주고 한 번 확인한다(7a~7d 개별 질문은 첫 회만).

```
loop:
  loop_iter += 1
  done.sh·done.sh.frozen 이 있는지, cmp -s 로 같은지 → 다르면 「약하게 만들지 않는다」 절차
  Step 7 묶음(빌드·타입·린트·테스트) + done.sh 실행
  실패 집합 F = 실패한 Step 7 항목(BUILD/TYPE/LINT/TEST) ∪ FAIL 인 AC (∪ DONESH)
  F 가 비었고 done.sh exit 0 → 루프 종료, Ship 으로
  STATE.md Done Loop 표에 한 줄 기록
  멈춤 조건 검사 → 걸리면 BLOCKED
  실패 하나를 골라 새 가설로 고친다 → loop
```

`TEST` 는 테스트 실패와 함께, `tdd`/`full` 에서는 커버리지 80% 미만도 포함한다. `quick` 은 커버리지를 세지 않는다.

**DONESH (판정 장치 고장 — fail-closed)**: done.sh 종료 코드가 0·1 이 아니거나, `done.sh`·`done.sh.frozen` 이 없거나, 출력에 `DONE` 줄이 없으면 F 에 `DONESH` 를 넣고 **곧바로 BLOCKED** 로 멈춘다. 재시도할 수 없는 오류로 분류한다. 판정 장치가 고장 난 상태로 고치기를 이어 가면 무엇을 고쳤는지 알 수 없어서다.

**진척**은 실패 집합이 **엄격히 줄었을 때**만 인정한다(F_n ⊊ F_n-1). 다른 AC 가 새로 깨진 회귀, 같은 크기의 맞바꿈, done.sh 를 바꿔서 줄어든 것은 진척이 아니다. 기준선(iter 0)은 반복으로 세지 않는다. 그래서 iter 1 의 stall 은 늘 0 이고, n ≥ 2 부터 진척이 있으면 `stall = 0`, 없으면 `stall += 1` 이다.

**멈춤 조건 (하나라도 걸리면 BLOCKED)**:

| 조건 | 판정 |
|------|------|
| 진척 없는 반복 | 같은 실패 항목이 **진척 없이 연속 3회** 실패했다 — `stall ≥ 2` 이면서 그 항목이 F_n·F_n-1·F_n-2 에 모두 있다(n-2 ≥ 1, 기준선 제외) |
| 전체 상한 | `loop_iter` 이 **10** 에 닿았다 — 진척이 있어도 멈춘다 |
| 재시도 무의미 | `DONESH`, 또는 [debugging.md 에러 분류](debugging.md#진척-없는-3회-회로차단기--에러-분류)의 **요청 자체 오류·리뷰 의견 충돌**, 또는 일시적 오류가 즉시 재시도에서도 실패한 환경 문제(자격 증명·외부 서비스) |

두 예로 기준선을 세지 않는다는 뜻을 보인다.

| 반복 | 예 1 실패 집합 | stall | 예 2 실패 집합 | stall |
|------|--------------|-------|--------------|-------|
| 0 (기준선) | AC-01 AC-02 AC-03 | — | AC-01 AC-02 | — |
| 1 | AC-02 AC-03 | 0 | AC-01 AC-02 | 0 |
| 2 | AC-02 AC-03 | 1 | AC-01 AC-02 | 1 → 계속 |
| 3 | AC-02 AC-04 | 2 → **BLOCKED** | AC-01 AC-02 | 2 → **BLOCKED** |

예 1 은 3회째에 크기가 같은 맞바꿈이 나와 줄지 않았고, AC-02 가 iter 1~3 에서 연속 실패했다. 예 2 는 기준선까지 세면 iter 2 에서 멈추겠지만, 기준선을 빼므로 iter 3 까지 간다.

멈춤 기준은 "같은 실패가 진척 없이 3회, 전체 10회"다. 실패를 하나씩 줄여 가는 동안은 다른 실패를 고치는 것이라 세지 않고, 대신 상한 10 이 전체 폭주를 막는다. BLOCKED 가 되면 디버깅 전담 서브에이전트(있으면 `debug-specialist`)에 넘기거나 사용자에게 보고한다. 보고에는 Done Loop 표 전체, 마지막 done.sh 출력, 시도한 가설 목록을 붙이고 `--resume` 으로 이어 갈 수 있게 STATE.md `status: blocked` 를 남긴다.

**STATE.md 기록 형식** (매 반복 한 줄, 가설은 반복마다 달라야 한다 — 같은 수정의 반복은 재시도가 아니다):

```markdown
### Done Loop
| iter | 실패 집합 | 변화 | stall | 이번 가설 |
|------|----------|------|-------|----------|
| 0 | AC-01 AC-02 AC-03 | 기준선 | — | — |
| 1 | AC-02 AC-03 | 줄어듦 | 0 | 토큰 서명 키를 env 에서 읽게 |
| 2 | AC-02 AC-03 | 같음 | 1 | 401 분기 순서 수정 |
```

## done.sh 를 약하게 만들지 않는다

결과를 본 뒤 판정 기준을 바꾸면 검증이 아니다. 그래서 동결 뒤에는 이렇게 한다.

- **매 반복 `cmp -s done.sh.frozen done.sh` 로 비교한다.** 다르면 `diff -u done.sh.frozen done.sh` 를 STATE.md 와 완료 보고에 남기고, **왜 바꿨는지 한 문장**을 붙인다(예: "AC-03 명령이 테스트 이름 오타로 늘 FAIL 이었다"). 바꾼 반복의 실패 집합 감소는 진척으로 치지 않는다. 완료 보고에는 처음 동결본과의 누적 diff 를 붙여야 하므로, 동결본을 갱신하기 전에 `cp -n done.sh.frozen done.sh.frozen.0` 으로 처음 것을 한 번만 남긴다. 그다음 `cp done.sh done.sh.frozen` 으로 동결본을 새로 한다
- **AC 제거, FAIL→MANUAL 변경, 조건을 느슨하게 하는 수정은 사용자만 정한다.** 번호 붙인 평문 질문으로 묻고, 답을 받기 전에는 그 AC 를 FAIL 로 둔다
- **금지 — 판정을 무력화하는 수정**: `|| true`, 조기 `exit 0`, `check` 를 지우거나 주석 처리(`EXPECTED` 를 같이 줄여도 diff 에 드러난다), pytest `-k`·`--deselect`·`skip` 으로 대상 빼기, AC 를 검증하는 테스트의 단언을 약하게 바꾸기
- 마지막 것은 done.sh 를 안 건드려도 같은 효과라, 완료 보고에 테스트 diff 도 함께 붙인다. `tdd`/`full` 은 `git diff <tests_frozen_at> -- <AC 매핑 테스트 파일>`(RED 커밋이 테스트를 담고 있어 실제 변경만 나온다), `--sdd` 는 파일마다 `git diff <그 파일을 추가한 커밋> -- <파일>`, `quick` 은 파일마다 `diff -u "$DONE_DIR/tests.frozen/<파일>" <파일>` 을 돌린다(`rsync -R` 이 저장소 상대 경로를 그대로 두므로 경로가 같다)

## 무인 장시간 실행 — ralph-loop

**기본은 세션 안 루프**다 — 위 루프를 이 대화에서 그대로 돈다. 사람이 자리를 비우고 오래 돌릴 때만 설치된 `ralph-loop` 플러그인을 쓴다. 이 플러그인은 응답이 끝날 때마다 같은 프롬프트를 다시 넣고, 마지막 응답에 `<promise>` 문구가 있으면 멈춘다.

**promise 문구 자체는 위조할 수 있다.** 멈춤 훅은 마지막 응답 글자에 그 문구가 있는지만 본다 — 모델이 쓴 마커다. 그래서 promise 는 **같은 응답 안에서 done.sh 가 exit 0 으로 끝난 직후에만** 내고, 그 응답에 done.sh 출력 전문(`DONE n/n` 포함)을 붙인다. 사람은 promise 가 아니라 그 출력과 STATE.md Done Loop 표로 완료를 확인하고, `bash <done.sh 절대 경로>; echo "exit=$?"` 를 직접 실행한다.

**시작은 사용자가 직접 입력한다.** 플러그인 명령은 `hide-from-slash-command-tool` 이라 모델이 띄울 수 없다. 또 인자가 셸 한 줄에 그대로 들어가서 여러 줄 프롬프트가 깨진다(anthropics/claude-code #16037). 그래서 지시는 [ralph-prompt.md](ralph-prompt.md) 에 두고, 인자는 `<`·`>` 없는 한 줄로 쓴다. 아래 `<절대 경로>` 는 `ls -d ~/.claude/plugins/cache/*/sos/*/references | tail -1` 로 나온 경로로 바꿔 넣는다.

```
/ralph-loop Follow <절대 경로>/references/ralph-prompt.md exactly --max-iterations 10 --completion-promise DONE_SH_EXIT_0
```

- `--max-iterations 10` 은 이 문서의 전체 상한 10 과 같은 값이다. `config/references/advanced-patterns.md` 의 Ralph Loop 줄도 이 값을 따른다
- BLOCKED 로 멈출 때는 promise 를 쓰지 않는다. 플러그인 상태 파일을 지워서 끝낸다(`/ralph-loop:cancel-ralph` 와 같은 동작)
- 무인 실행이므로 Ship 전에 독립 리뷰를 요청 없이도 돌린다 — 리뷰를 요청할 사람이 없기 때문이다
- **실행으로 검증하지 않은 절차다.** 플러그인 1.0.1 의 `stop-hook.sh`·`setup-ralph-loop.sh` 를 읽고 맞춘 것이고, 실제로 돌려 본 기록은 아직 없다
