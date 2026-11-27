#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# 영수증 훅(test-receipt.sh)과 가드(pre-tool-use-guard.sh)의 동작 계약
#   - 영수증 위치: <git common dir>/claude/receipts.json  { "trees": { "<tree>": {head, command, ts} } }
#   - 레드팀(2026-09-15)이 찾은 우회 케이스는 전부 부정 테스트로 고정한다

load 'helpers'

setup() {
    REPO="$(make_git_repo)"
    export CLAUDE_PROJECT_DIR="$REPO"
    export TEST_RECEIPT_REQUIRED=1
    unset TEST_CMD
    cd "$REPO" || return 1
    RECEIPT="$REPO/.git/claude/receipts.json"
}

teardown() {
    git -C "$REPO" worktree prune 2>/dev/null || true
    rm -rf "$REPO" "$REPO-wt"
}

receipt_has() { jq -e --arg t "$1" '.trees[$t]' "$RECEIPT" >/dev/null 2>&1; }
run_receipt()  { bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json "$1" false "${2:-{\}}")"; }
run_guard()    { run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "$1")"; }

# ─── test-receipt.sh: 발급 ──────────────────────────────────────────────

@test "receipt: 실제 페이로드(exit_code 없음)로 영수증을 쓰고 tree 가 HEAD 트리와 같다 (clean tree)" {
    run_receipt 'pytest tests/'
    [ -f "$RECEIPT" ]
    receipt_has "$(git rev-parse 'HEAD^{tree}')"
    [ "$(jq -r --arg t "$(git rev-parse 'HEAD^{tree}')" '.trees[$t].command' "$RECEIPT")" = "pytest tests/" ]
}

@test "receipt: 비0 종료(PostToolUseFailure 페이로드)는 영수증을 쓰지 않는다" {
    run bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_failure_json 'npm test' 'Exit code 1')"
    [ "$status" -eq 0 ]
    [ ! -f "$RECEIPT" ]
}

@test "receipt: interrupted · returnCodeInterpretation · backgroundTaskId · 구버전 exit_code≠0 은 거부" {
    bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' true)";                                  [ ! -f "$RECEIPT" ]
    run_receipt 'pytest' '{"returnCodeInterpretation":"No tests collected"}';                                   [ ! -f "$RECEIPT" ]
    run_receipt 'pytest' '{"backgroundTaskId":"bg_1"}';                                                         [ ! -f "$RECEIPT" ]
    run_receipt 'pytest' '{"exit_code":1}';                                                                     [ ! -f "$RECEIPT" ]
    run_receipt 'pytest' '{"exit_code":0}';                                                                     [ -f "$RECEIPT" ]
}

@test "receipt: Bash 가 아닌 도구의 페이로드는 거부" {
    run bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false | jq -c '.tool_name="mcp__x__run"')"
    [ ! -f "$RECEIPT" ]
}

@test "receipt: 테스트가 아닌 명령은 거부" {
    run_receipt 'ls -la'; [ ! -f "$RECEIPT" ]
}

@test "receipt: 래퍼(rtk · uv run · poetry run · npx · bundle exec · timeout)를 벗기고 러너를 인식한다" {
    for cmd in 'rtk pytest -q' 'uv run pytest' 'poetry run pytest tests/' 'npx vitest run' 'bundle exec rspec' 'timeout 600 go test ./...' 'python3 -m pytest'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ -f "$RECEIPT" ] || { echo "not recognized: $cmd"; return 1; }
    done
}

@test "receipt: 다양한 러너를 인식한다" {
    for cmd in 'bats tests/' 'cargo test' './gradlew test' 'pnpm test' 'dotnet test' 'npm run test:unit' 'playwright test' 'make test' 'deno test' 'mix test' 'flutter test' 'swift test'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ -f "$RECEIPT" ] || { echo "not recognized: $cmd"; return 1; }
    done
}

@test "receipt: 테스트를 돌리지 않는 옵션은 거부 (--version --help --collect-only --dry-run -DskipTests -x test --list*)" {
    for cmd in 'pytest --version' 'pytest --help' 'pytest --collect-only -q' 'bats --version' 'bats --count tests/' 'go test -run ^$ ./...' \
               'npm test -- --help' 'jest --listTests' 'vitest --run --passWithNoTests' 'cargo test --no-run' 'dotnet test --list-tests' \
               'mvn test -DskipTests' './gradlew test --dry-run' 'gradle test -x test' 'rspec --dry-run' 'npm run test:lint'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
}

@test "receipt: 부분 실행 선택자(-k -m :: -run --testPathPattern -t --filter)는 거부" {
    for cmd in 'pytest -k smoke' 'pytest -m "not slow"' 'pytest tests/test_a.py::test_one' 'go test -run TestX ./...' \
               'npm test -- --testPathPattern=trivial' 'jest -t "renders"' 'dotnet test --filter Category=Fast'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
}

@test "receipt: 다른 루트·바뀐 파일만·테스트 없음 허용·목록만 보는 옵션은 거부 (Codex 리뷰 PR #49)" {
    for cmd in 'pnpm test --root=../api' 'vitest run --root ../api' 'jest --rootDir ../api' 'jest --roots ../api' \
               'vitest --pass-with-no-tests' 'jest --passWithNoTests=true' 'pnpm test list' 'vitest list' 'vitest related src/a.ts' 'vitest bench' \
               'jest --onlyChanged' 'jest -o' 'pnpm test -- --findRelatedTests src/a.ts' 'jest --lastCommit' 'jest --onlyFailures' \
               'vitest --shard=1/3' 'jest --shard 1/3' \
               'jest --only-changed' 'jest --find-related-tests src/a.ts' 'jest --root-dir ../api' 'vitest --test-name-pattern=smoke' \
               'jest --last-commit' 'jest --only-failures' 'pnpm test -- list' 'npm test -- related src/a.ts' 'pnpm test -- -o' \
               'vitest run --project unit' 'vitest --exclude x' 'jest --testMatch x' 'jest --test-regex x' 'jest --selectProjects a' \
               'jest --testPathIgnorePatterns x' 'jest --runTestsByPath a.test.js'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
    # 전체를 돌리는 흔한 옵션은 그대로 인정
    # 짧은 -o · -f 와 하위 명령은 Vitest·Jest·패키지 스크립트에서만 본다
    for cmd in 'pytest -ra' 'mocha -r ts-node/register' 'bats -r tests/' 'pytest -o console_output_style=classic' 'rspec -f documentation' 'pytest list' 'pytest --rootdir=. tests/' 'pytest --count=2' 'jest --ci --coverage' 'vitest run --reporter=verbose' 'pnpm test -- --coverage'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ -f "$RECEIPT" ] || { echo "not recognized: $cmd"; return 1; }
    done
}

@test "receipt: 러너가 체인의 마지막이 아니거나 실행이 보장되지 않으면 거부 (; true · || true · | tail · ls || pytest)" {
    for cmd in 'pytest tests/; true' 'pytest tests/ || true' 'pytest 2>&1 | tail -20' 'ls || pytest' 'false; pytest --version' 'cat x | pytest'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
    # && 와 ; 뒤의 러너는 인정
    rm -f "$RECEIPT"; run_receipt 'ls && pytest';   [ -f "$RECEIPT" ]
    rm -f "$RECEIPT"; run_receipt 'true; pytest';   [ -f "$RECEIPT" ]
}

@test "receipt: cd 접두(다른 디렉터리·하위 디렉터리)·프로젝트 밖 경로·명령 치환은 거부, 프로젝트 루트로의 cd 는 허용" {
    mkdir -p tests/unit
    for cmd in 'cd /tmp && pytest' 'cd tests/unit && pytest' 'pytest /some/other/project/tests' 'pytest $(echo tests)'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
    rm -f "$RECEIPT"; run_receipt "cd $REPO && pytest";   [ -f "$RECEIPT" ]
    rm -f "$RECEIPT"; run_receipt "cd . && pytest";       [ -f "$RECEIPT" ]
}

@test "receipt: 패키지 매니저의 디렉터리 옵션(pnpm -C/--dir · npm --prefix · yarn/bun --cwd)을 인식한다 — 모노레포 (측정 발견 4)" {
    mkdir -p apps/web
    for cmd in 'pnpm -C apps/web test' 'pnpm --dir apps/web test' 'pnpm --dir=apps/web test' 'npm --prefix apps/web test' \
               'yarn --cwd apps/web test' 'bun --cwd apps/web test' 'pnpm -C apps/web run test' 'rtk pnpm -C apps/web test'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ -f "$RECEIPT" ] || { echo "not recognized: $cmd"; return 1; }
    done
    # 디렉터리 옵션이 있어도 부분 실행·테스트 아닌 스크립트는 그대로 거부
    ln -s apps/web web-link
    # 영수증 대상과 실제 실행 위치가 갈라질 수 있는 형태는 거부 (Codex 리뷰): 뒤에 온 옵션 · 중복 · npm_config_* · cd 동반 ·
    # 심볼릭 링크 · ~ 값
    for cmd in 'pnpm -C apps/web test -- -t smoke' 'pnpm -C apps/web lint' 'pnpm -C apps/web' 'pnpm -C' \
               'npm test --prefix apps/web' 'pnpm test -C apps/web' 'pnpm -C apps/web --dir . test' \
               'npm_config_prefix=apps/web npm test' 'env NPM_CONFIG_PREFIX=apps/web npm test' \
               "cd $REPO && pnpm -C apps/web test" 'pnpm -C web-link test' "pnpm -C '~/x' test"; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
}

@test "receipt: 앞 세그먼트의 npm_config_* · 경로 중간의 심볼릭 링크도 거부한다 (Codex 리뷰 PR #49)" {
    mkdir -p apps/web
    ln -s apps apps-link
    for cmd in 'export npm_config_prefix=apps/web; npm test' 'export NPM_CONFIG_PREFIX=apps/web && npm test' \
               'pnpm -C apps-link/web test' 'pnpm -C ./apps-link/web/ test' 'pnpm -C apps-link/../apps/web test' \
               'pnpm -C missing/../apps-link/web test' 'export npm_config_prefix+=apps/web; npm test' \
               'A=npm; B=_config_prefix; export "${A}${B}=apps/web"; npm test' \
               'A=npm_config_prefix=apps/web; env "$A" npm test' 'eval "export $X"; npm test' \
               'command export "${A}${B}=apps/web"; npm --prefix apps/web test' \
               "set -a; printf -v \"\${A}\${B}\" '%s' apps/web; pnpm -C apps/web test" \
               'true && pnpm -C apps/web test' 'pnpm -C "$D" test' 'pnpm -C apps/web test & true' \
               'pnpm -C apps/web test | tee log' 'pnpm -C app[s]/web test' 'pnpm -C apps/w?b test' \
               'pnpm -C apps/* test' $'pnpm -C "apps/web\r" test' 'pnpm -C apps\\/web test' \
               "pnpm -C apps/web test '>' --help" 'env PATH=/tmp/fake pnpm -C apps/web test' \
               'FOO=1 pnpm -C apps/web test' 'pnpm -Capps/web test'; do
        rm -f "$RECEIPT"; run_receipt "$cmd"
        [ ! -f "$RECEIPT" ] || { echo "wrongly accepted: $cmd"; return 1; }
    done
    # 링크 없는 경로는 .. 가 섞여도 인정
    rm -f "$RECEIPT"; run_receipt 'pnpm -C apps/../apps/web test';   [ -f "$RECEIPT" ]
    rm -f "$RECEIPT"; run_receipt 'pnpm -C apps/web test > log';   [ -f "$RECEIPT" ]
    rm -f "$RECEIPT"; run_receipt "pnpm -C ../$(basename "$REPO")/apps/web test";   [ -f "$RECEIPT" ]
}

@test "receipt: 디렉터리 옵션이 다른 저장소를 가리키면 그 저장소에 영수증을 쓴다 — 가드는 git -C 로 그 영수증을 본다" {
    OTHER="$(make_git_repo)"
    mkdir -p "$OTHER/apps/web"
    run_receipt "pnpm -C $OTHER/apps/web test"
    [ ! -f "$RECEIPT" ]
    jq -e --arg t "$(git -C "$OTHER" rev-parse 'HEAD^{tree}')" '.trees[$t]' "$OTHER/.git/claude/receipts.json"
    git -C "$OTHER" checkout -q -b feat/x
    run_guard "git -C $OTHER push origin feat/x"
    status_other="$status"
    # 저장소가 아닌 곳·없는 디렉터리는 영수증을 어디에도 쓰지 않는다
    NOREPO="$(mktemp -d)"
    run_receipt "pnpm -C $NOREPO test"
    run_receipt "pnpm -C $OTHER/missing test"
    rm -rf "$OTHER" "$NOREPO"
    [ "$status_other" -eq 0 ]
    [ ! -f "$RECEIPT" ]
    [ ! -d "$NOREPO/.git" ]
}

@test "receipt: TEST_CMD 강화 모드 — 정확히 같은 명령만 인정 (rtk 접두사는 허용)" {
    export TEST_CMD='pnpm test -- --coverage'
    run_receipt 'pytest';                          [ ! -f "$RECEIPT" ]
    run_receipt 'pnpm test';                       [ ! -f "$RECEIPT" ]
    run_receipt 'rtk pnpm test -- --coverage';     [ -f "$RECEIPT" ]
}

@test "receipt: TEST_CMD 강화 모드도 디렉터리 옵션의 저장소에 기록한다" {
    OTHER="$(make_git_repo)"
    export TEST_CMD="pnpm -C $OTHER test"
    run_receipt "pnpm -C $OTHER test"
    ok_other="$(jq -e --arg t "$(git -C "$OTHER" rev-parse 'HEAD^{tree}')" '.trees[$t]' "$OTHER/.git/claude/receipts.json" > /dev/null && echo yes)"
    rm -rf "$OTHER"
    [ "$ok_other" = yes ]
    [ ! -f "$RECEIPT" ]
}

@test "receipt: TEST_CMD 강화 모드도 다른 디렉터리로의 cd · cd 와 디렉터리 옵션 동반은 거부한다 (Codex 리뷰 PR #49)" {
    OTHER="$(make_git_repo)"
    mkdir -p apps/web
    for tc in "cd $OTHER && pnpm test" "cd $REPO && pnpm -C apps/web test" 'export npm_config_prefix=apps/web; npm test' \
              '{ builtin export "${A}${B}=apps/web"; pnpm -C apps/web test; }' \
              'builtin export `printf %s_%s npm config_prefix`=apps/web; pnpm -C apps/web test' \
              "pnpm '--dir' $OTHER test || true" "pnpm -C $OTHER test & true" "pnpm -C$OTHER test"; do
        export TEST_CMD="$tc"
        rm -f "$RECEIPT"; run_receipt "$tc"
        [ ! -f "$RECEIPT" ] && [ ! -f "$OTHER/.git/claude/receipts.json" ] || { rm -rf "$OTHER"; echo "wrongly accepted: $tc"; return 1; }
    done
    rm -rf "$OTHER"
    # 프로젝트 루트로의 cd 는 그대로 인정
    export TEST_CMD="cd $REPO && pnpm test"
    rm -f "$RECEIPT"; run_receipt "$TEST_CMD";   [ -f "$RECEIPT" ]
    # npm 의 -C 는 --prefix 별칭 — 그 저장소에 쓴다
    OTHER="$(make_git_repo)"
    export TEST_CMD="npm -C $OTHER test"
    rm -f "$RECEIPT"; run_receipt "$TEST_CMD"
    ok_other="$(jq -e --arg t "$(git -C "$OTHER" rev-parse 'HEAD^{tree}')" '.trees[$t]' "$OTHER/.git/claude/receipts.json" > /dev/null && echo yes)"
    rm -rf "$OTHER"
    [ "$ok_other" = yes ]
    [ ! -f "$RECEIPT" ]
}

@test "receipt: 작업 트리에 미커밋 변경이 있으면 tree 가 HEAD 트리와 다르고, 그대로 커밋하면 같아진다 (내용 해시)" {
    printf 'changed\n' > README.md
    run_receipt 'pytest'
    if receipt_has "$(git rev-parse 'HEAD^{tree}')"; then echo "HEAD tree must not be receipted yet"; return 1; fi
    git add README.md && git commit -q -m "change"
    receipt_has "$(git rev-parse 'HEAD^{tree}')"
}

@test "receipt: worktree 에서 실행하면 그 worktree 의 트리를 공용 영수증에 기록한다 (cwd 기준)" {
    git worktree add -q "$REPO-wt" -b feat/wt
    printf 'wt\n' > "$REPO-wt/wt.txt"
    git -C "$REPO-wt" add wt.txt && git -C "$REPO-wt" commit -q -m "wt"
    ( cd "$REPO-wt" && bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false)" )
    receipt_has "$(git -C "$REPO-wt" rev-parse 'HEAD^{tree}')"
    [ -f "$RECEIPT" ]   # 공용 .git 아래 한 파일
}

@test "receipt: 잘못된 JSON 입력은 조용히 exit 0 (fail-open)" {
    run bash "$HOOKS_DIR/test-receipt.sh" <<< "not json"
    [ "$status" -eq 0 ]
}

# ─── pre-tool-use-guard.sh: 영수증 게이트 ───────────────────────────────

@test "guard: 영수증 없이 git push / gh pr create / gh pr new / gh api POST pulls 는 차단(exit 2)" {
    for c in 'git push origin feat/x' 'gh pr create --title x --body y' 'gh pr new --fill' 'gh -R o/r pr create -f' 'gh api -X POST repos/o/r/pulls -f title=x'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}

@test "guard: 테스트 통과 트리와 push 되는 트리가 같으면 허용" {
    run_receipt 'pytest'
    run_guard 'git push origin main:feat/x';   [ "$status" -eq 0 ]   # 대상은 feat/x, 소스는 main(테스트됨)
    git checkout -q -b feat/x
    run_guard 'git push origin feat/x';        [ "$status" -eq 0 ]
    run_guard 'git push -u origin feat/x';     [ "$status" -eq 0 ]
    run_guard 'gh pr create --fill';           [ "$status" -eq 0 ]
}

@test "guard: 테스트 후 편집·커밋하면 push 되는 트리가 달라져 차단" {
    git checkout -q -b feat/x
    run_receipt 'pytest'
    printf 'untested\n' > README.md
    git add README.md && git commit -q -m "untested change"
    run_guard 'git push origin feat/x'; [ "$status" -eq 2 ]
}

@test "guard: 편집 후 테스트를 다시 통과하고 커밋하면 허용" {
    git checkout -q -b feat/x
    printf 'retested\n' > README.md
    run_receipt 'pytest'
    git add README.md && git commit -q -m "retested change"
    run_guard 'git push origin feat/x'; [ "$status" -eq 0 ]
}

@test "guard: 부분 스테이징 — 작업 트리는 테스트됐지만 커밋된 트리는 아니면 차단" {
    git checkout -q -b feat/p
    printf 'a\n' > a.py; printf 'b\n' > b.py
    run_receipt 'pytest'
    git add a.py && git commit -q -m "only a"
    run_guard 'git push origin feat/p'; [ "$status" -eq 2 ]
}

@test "guard: 다른 브랜치·refspec 소스의 트리를 검사한다 (main 테스트로 feat/untested 를 밀 수 없다)" {
    run_receipt 'pytest'                       # main 트리에 영수증
    git checkout -q -b feat/untested
    printf 'x\n' > x.txt && git add x.txt && git commit -q -m "untested"
    git checkout -q main
    run_guard 'git push origin feat/untested';                                   [ "$status" -eq 2 ]
    run_guard 'git push origin refs/heads/feat/untested:refs/heads/feat/untested'; [ "$status" -eq 2 ]
    run_guard 'git push origin feat/untested~0:feat/y';                          [ "$status" -eq 2 ]
    run_guard 'git push --all origin';                                           [ "$status" -eq 2 ]
    run_guard 'git push --mirror origin';                                        [ "$status" -eq 2 ]
}

@test "guard: worktree 에서 커밋한 트리는 그 worktree 의 cwd 기준으로 검사한다" {
    git worktree add -q "$REPO-wt" -b feat/wt
    printf 'wt\n' > "$REPO-wt/wt.txt"
    git -C "$REPO-wt" add wt.txt && git -C "$REPO-wt" commit -q -m "wt"
    ( cd "$REPO-wt" && run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json 'git push origin feat/wt')"; [ "$status" -eq 2 ] )
    ( cd "$REPO-wt" && bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false)" )
    ( cd "$REPO-wt" && run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json 'git push origin feat/wt')"; [ "$status" -eq 0 ] )
}

@test "guard: 래퍼·따옴표·경로·옵션으로 감싼 push 도 게이트를 탄다" {
    for c in 'command git push origin feat/x' 'env git push origin feat/x' 'env TEST_RECEIPT_REQUIRED=0 git push origin feat/x' \
             'TEST_RECEIPT_REQUIRED=0 git push origin feat/x' 'timeout 60 git push origin feat/x' 'nohup git push origin feat/x' \
             '/usr/bin/git push origin feat/x' '\git push origin feat/x' 'git "push" origin feat/x' "git pu''sh origin feat/x" \
             'git -C . push origin feat/x' 'git -c push.default=current push origin feat/x' 'GIT_DIR=.git git push origin feat/x' \
             'rtk rtk git push origin feat/x' 'git send-pack origin feat/x' 'true && git push origin feat/x' 'git status; git push origin feat/x' \
             $'git status\ngit push origin feat/x' 'gh --repo o/r pr create --fill' 'hub pull-request'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}

@test "guard: 위임 실행(sh -c · eval · xargs · \$( ) · 변수 서브커맨드 · alias) 안의 push/PR 은 무조건 차단" {
    run_receipt 'pytest'   # 영수증이 있어도
    for c in 'sh -c "git push origin feat/x"' 'bash -c "git push origin feat/x"' 'eval "git push origin feat/x"' \
             'echo "git push origin feat/x" | sh' 'xargs -I{} git push origin {} <<< feat/x' 'git $(echo push) origin feat/x' \
             'p=push; git $p origin feat/x' 'git config alias.p push && git p origin feat/x' 'git -c alias.p=push p origin feat/x' \
             'python3 -c "import subprocess; subprocess.run([\"git\",\"push\"])"' 'gh alias set pc "pr create"; gh pc'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}

@test "guard: 리다이렉션(2>&1 · >log)은 브랜치로 오인하지 않는다" {
    git checkout -q -b feat/x
    run_receipt 'pytest'
    run_guard 'git push -u origin feat/x 2>&1';              [ "$status" -eq 0 ]
    run_guard 'git push origin feat/x > push.log 2>&1';      [ "$status" -eq 0 ]
    run_guard 'git push origin feat/x 2>&1 | tail -5';       [ "$status" -eq 0 ]
    # 리다이렉션이 있어도 대상 검사는 그대로
    run_guard 'git push origin HEAD:main 2>&1';              [ "$status" -eq 2 ]
}

@test "receipt: 리다이렉션이 붙은 러너도 인식한다 (bats tests/ 2>&1 · > log)" {
    run_receipt 'bats tests/ 2>&1';           [ -f "$RECEIPT" ]
    rm -f "$RECEIPT"; run_receipt 'pytest > test.log 2>&1'; [ -f "$RECEIPT" ]
}

@test "guard: 삭제·태그 전용 push 와 --help · --dry-run 은 영수증 없이 허용" {
    for c in 'git push origin --delete feat/x' 'git push origin :feat/x' 'git push --tags origin' 'git push origin feat/x --help' 'gh pr create --help' 'git push --dry-run origin feat/x'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "wrongly blocked: $c"; return 1; }
    done
}

@test "guard: TEST_RECEIPT_REQUIRED=0 (settings env, 사람 결정) 이면 영수증 없이도 push 허용" {
    export TEST_RECEIPT_REQUIRED=0
    git checkout -q -b feat/x
    run_guard 'git push origin feat/x'; [ "$status" -eq 0 ]
}

# ─── pre-tool-use-guard.sh: force / main ────────────────────────────────

@test "guard: 영수증이 있어도 force push 변형은 전부 차단 (--force -f +ref -fu --force=…)" {
    run_receipt 'pytest'
    for c in 'git push --force origin feat/x' 'git push -f origin feat/x' 'git push origin +feat/x' 'git push origin feat/x -f' 'git push -fu origin feat/x' 'git push --force=true origin feat/x'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    run_guard 'git push --force-with-lease origin main:feat/x'; [ "$status" -eq 0 ]   # lease 는 허용 (소스 main 은 테스트됨)
}

@test "guard: main/master 로 향하는 push 는 refspec 대상·리모트 이름과 무관하게 차단, 인자 없는 push 는 현재 브랜치가 main 이면 차단" {
    run_receipt 'pytest'
    for c in 'git push origin main' 'git push origin HEAD:main' 'git push origin feat/x:main' 'git push origin feat/x:refs/heads/main' \
             'git push -u origin main' 'git push --set-upstream origin main' 'git push upstream main' 'git push origin master:main' \
             'git push origin main --no-verify' 'git push origin :main' 'git push'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    git checkout -q -b feat/x
    run_guard 'git push'; [ "$status" -eq 0 ]   # feat/x 위의 인자 없는 push 는 게이트만 (영수증 있음)
}

# ─── pre-tool-use-guard.sh: 위험 명령 · 시크릿 · 훅 보호 ─────────────────

@test "guard: 복합 명령 안의 위험 명령은 읽기 전용 접두사로 숨겨도 차단 (quick-exit 우회 방지)" {
    for c in 'echo hi && git push --force origin main' 'ls; git reset --hard HEAD~1' 'cat x | git push origin main' \
             'git status && git push --force origin main' "$(printf 'true\nrm -rf /')" "$(printf '# comment\ngit push origin main')" \
             'which git && kubectl delete namespace prod' 'echo; psql -c "DROP TABLE users"'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}

@test "guard: rm -rf 변형(-fr · -r -f · -- · --no-preserve-root)은 차단, /tmp/x 같은 하위 경로는 허용" {
    for c in 'rm -rf /' 'rm -fr /' 'rm -r -f /' 'rm -rf -- /' 'rm -rf ~' 'rm -rf $HOME' 'rm -rf ..' 'rm -rf --no-preserve-root /'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    run_guard 'rm -rf /tmp/x';        [ "$status" -eq 0 ]
    run_guard 'rm -rf build/ dist/';  [ "$status" -eq 0 ]
}

@test "guard: Bash 로 .env 파일을 읽거나 쓰는 명령은 차단, .env.example 은 허용" {
    for c in 'cat .env' 'sed -i "s/KEY=.*/KEY=x/" .env' 'cp .env /tmp/leak' 'printf "SECRET=1\n" >> .env' 'tee .env.production <<< "X=1"' 'cat config/.env.local'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    run_guard 'cat .env.example';  [ "$status" -eq 0 ]
    run_guard 'cp .env.example .env.sample'; [ "$status" -eq 0 ]
}

@test "guard: 훅·설정·영수증 파일을 Bash 로 쓰거나 Edit/Write 로 여는 것은 차단, 읽기는 허용" {
    for c in 'printf x > .claude/settings.json' 'sed -i "s/exit 2/exit 0/" .claude/hooks/pre-tool-use-guard.sh' 'rm .claude/hooks/pre-tool-use-guard.sh' \
             'cp foo .claude/hooks/x.sh' 'chmod -x .claude/hooks/pre-tool-use-guard.sh' 'printf "{}" > .git/claude/receipts.json' \
             'echo 0 > .claude/settings.local.json'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    for f in '.claude/settings.json' '.claude/settings.local.json' '.claude/hooks/pre-tool-use-guard.sh' "$REPO/.git/claude/receipts.json"; do
        run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_edit_json "$f")"; [ "$status" -eq 2 ] || { echo "edit not blocked: $f"; return 1; }
    done
    run_guard 'cat .claude/hooks/pre-tool-use-guard.sh';   [ "$status" -eq 0 ]
    run_guard 'git diff .claude/settings.json';            [ "$status" -eq 0 ]
    run_guard 'jq .trees .git/claude/receipts.json';       [ "$status" -eq 0 ]
    run_guard 'sed -n 1,5p .claude/hooks/hooklib.py';      [ "$status" -eq 0 ]
}

@test "guard: 오탐 없음 — 커밋 메시지 안의 'git push --force' · grep 결과 · README.env.md 편집 · 도움말" {
    for c in 'git commit -m "docs: explain git push --force policy"' 'git commit -m "fix: rm -rf / guard"' 'echo "git push origin main"' \
             'grep -rn "git push" docs/' 'git status | grep push' 'gh pr list' 'git help push' 'git log --oneline -5' 'rg -n TODO src/'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "wrongly blocked: $c"; return 1; }
    done
    run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_edit_json 'docs/README.env.md')"; [ "$status" -eq 0 ]
    # 'pre-push' 같은 파일명은 push 단어가 아니다 — 위임 실행이어도 허용
    run_guard 'bash -c "ls common/hooks/git/pre-push"';            [ "$status" -eq 0 ]
    run_guard 'shellcheck $(git ls-files "*.sh") .githooks/pre-push'; [ "$status" -eq 0 ]
    run_guard 'bash -c "git push origin feat/x"';                   [ "$status" -eq 2 ]
}

@test "guard: python3 가 없으면 fail-closed (exit 2, 설치 안내)" {
    BIN="$(mktemp -d)"
    for exe in bash sh sed tr head cat git jq mktemp cp rm dirname pwd; do
        p="$(command -v "$exe")" && ln -s "$p" "$BIN/$exe"
    done
    run env PATH="$BIN" bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json 'git push --force origin main')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"python3"* ]]
    rm -rf "$BIN"
}

# ─── pre-tool-use-guard.sh: 기존 동작 회귀 ──────────────────────────────

@test "guard: 읽기 전용 단순 명령은 통과" {
    for c in 'git status' 'ls -la' 'cat README.md' 'git log --oneline -5' 'git diff --stat'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "blocked: $c"; return 1; }
    done
}

@test "guard: git reset --hard · DROP TABLE · terraform destroy · kubectl delete ns 차단" {
    for c in 'git reset --hard HEAD~1' 'psql -c "drop table users"' 'terraform destroy -auto-approve' 'kubectl delete namespace prod'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}

@test "guard: .env / *.pem / *credentials* 편집은 차단, .env.example 은 허용" {
    for f in '.env' '.env.local' 'config/.env' 'app.env' 'server.pem' 'aws_credentials.json'; do
        run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_edit_json "$f")"; [ "$status" -eq 2 ] || { echo "edit not blocked: $f"; return 1; }
    done
    run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_edit_json '.env.example')"; [ "$status" -eq 0 ]
}

# ─── 리뷰 확정 버그 회귀 (2026-10-11) ───────────────────────────────────

@test "guard: 분석기 실패·파싱 불가 입력은 fail-closed (exit 2, 'guard analyzer failed')" {
    for input in 'not json' '[]' '"str"' ''; do
        run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$input"
        [ "$status" -eq 2 ] || { echo "not blocked: '$input'"; return 1; }
        [[ "$output" == *"guard analyzer failed"* ]] || { echo "message missing for '$input': $output"; return 1; }
    done
    # 분석기 자체가 죽는 경우 — 훅 사본의 hooklib.py 를 깨뜨린다
    H="$(mktemp -d)"
    cp "$HOOKS_DIR"/*.sh "$H/"
    printf 'import sys\nsys.exit(1)\n' > "$H/hooklib.py"
    run bash "$H/pre-tool-use-guard.sh" <<< "$(pre_tool_json 'git status')"
    rm -rf "$H"
    [ "$status" -eq 2 ]
    [[ "$output" == *"guard analyzer failed"* ]]
}

@test "guard: 형식이 올바른 무관한 이벤트는 허용 (빈 객체 · Read 도구)" {
    run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< '{}';                                                          [ "$status" -eq 0 ]
    run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}'; [ "$status" -eq 0 ]
}

@test "guard: 실행되지 않는 python3 스텁(Xcode CLT 없는 /usr/bin/python3)이면 fail-closed" {
    BIN="$(mktemp -d)"
    for exe in bash sh sed tr head cat git jq mktemp cp rm dirname pwd; do
        p="$(command -v "$exe")" && ln -s "$p" "$BIN/$exe"
    done
    printf '#!/bin/sh\necho "xcode-select: note: No developer tools were found" >&2\nexit 1\n' > "$BIN/python3"
    chmod +x "$BIN/python3"
    run env PATH="$BIN" bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json 'git status')"
    rm -rf "$BIN"
    [ "$status" -eq 2 ]
    [[ "$output" == *"python3"* ]]
}

@test "guard: main 위에서 HEAD · @ · HEAD:HEAD 로 현재 브랜치를 미는 push 는 차단 (-C 존중)" {
    run_receipt 'pytest'
    for c in 'git push -u origin HEAD' 'git push origin @' 'git push origin HEAD:HEAD' 'git push origin +HEAD' \
             'git push origin @:HEAD' 'git push origin' 'git push --set-upstream origin HEAD'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    # 다른 저장소(feat 브랜치)에서 -C 로 main 저장소를 가리켜도 차단
    OTHER="$(make_git_repo)"; git -C "$OTHER" checkout -q -b feat/o
    ( cd "$OTHER" && run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "git -C $REPO push origin HEAD")"; [ "$status" -eq 2 ] )
    rm -rf "$OTHER"
    # main 에서 HEAD:feat/y 는 허용, feat/x 위의 HEAD push 도 허용 (영수증 있음)
    run_guard 'git push origin HEAD:feat/y'; [ "$status" -eq 0 ]
    git checkout -q -b feat/x
    for c in 'git push -u origin HEAD' 'git push origin @' 'git push origin HEAD:HEAD'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "wrongly blocked on feat/x: $c"; return 1; }
    done
}

@test "guard: 따옴표 안의 연산자는 구분자가 아니다 (grep -n \"push|reset\")" {
    for c in 'grep -n "push|reset" a.sh' "grep -E 'push|pull' a.sh" 'rg "a && git push" docs/' 'git commit -m "x; git push origin main"'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "wrongly blocked: $c"; return 1; }
    done
    # 따옴표 밖 연산자는 그대로 구분
    run_guard 'grep -n "x" a.sh; git push --force origin feat/x'; [ "$status" -eq 2 ]
    run_guard "echo 'a|b' | sh -c 'git push origin feat/x'";       [ "$status" -eq 2 ]
}

@test "guard: .env 를 열지 않는 참조는 허용 (grep 패턴 · git check-ignore · ls · test), 여는 명령은 계속 차단" {
    for c in 'grep -c "\.env" .gitignore' 'git check-ignore -q .env' 'grep -n .env .gitignore' 'rg -n -e .env -g "*.env" docs/' \
             'test -f .env' '[ -f .env ]' 'ls -la .env' 'git ls-files .env'; do
        run_guard "$c"; [ "$status" -eq 0 ] || { echo "wrongly blocked: $c"; return 1; }
    done
    for c in 'cat .env' 'source .env' '. .env' 'cp .env x' 'sed -i "s/a/b/" .env' 'grep KEY .env' 'grep -e KEY .env' \
             'grep -f .env x' 'ls > .env' 'wc -l < .env' 'printf x >> .env' 'grep -c x .gitignore < .env' 'git check-ignore -q .env > .env'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
    run_guard 'cat .env.example'; [ "$status" -eq 0 ]
}

@test "guard: 영수증 없음 차단 메시지에 영수증 트리와의 차이 파일과 .gitignore 힌트를 보여준다" {
    git checkout -q -b feat/x
    mkdir coverage && printf 'cov\n' > coverage/lcov.info
    run_receipt 'pytest'                  # 미추적 coverage/ 가 영수증 트리에 들어간다
    rm -rf coverage                        # 커밋된 트리에는 없다
    run_guard 'git push origin feat/x'
    [ "$status" -eq 2 ]
    [[ "$output" == *"coverage/lcov.info"* ]] || { echo "$output"; return 1; }
    [[ "$output" == *".gitignore"* ]]
}

@test "receipt: 미추적 파일이 영수증 트리에 포함되면 additionalContext 로 경고한다" {
    printf 'cov\n' > lcov.info
    run bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lcov.info"* ]] || { echo "$output"; return 1; }
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | test("untracked"))' >/dev/null
    rm lcov.info
    run bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false)"
    [ -z "$output" ]
}

# ─── auto-format.sh: 레지스트리 다운로드 금지 ───────────────────────────

@test "auto-format: bun 저장소에서도 bunx 로 레지스트리 패키지를 받지 않고, 로컬 도구가 없으면 안내 후 건너뛴다" {
    BIN="$(mktemp -d)"
    ln -s "$(python3 -c 'import sys; print(sys.executable)')" "$BIN/python3"
    for b in bunx bun; do
        printf '#!/bin/sh\necho "%s $*" >> "%s/called"\n' "$b" "$BIN" > "$BIN/$b"; chmod +x "$BIN/$b"
    done
    : > bun.lock; printf 'const a=1\n' > a.ts
    run env PATH="$BIN:/usr/bin:/bin" bash "$HOOKS_DIR/auto-format.sh" <<< "$(jq -nc --arg f "$PWD/a.ts" '{tool_input:{file_path:$f}}')"
    [ "$status" -eq 0 ]
    [ ! -f "$BIN/called" ] || { cat "$BIN/called"; rm -rf "$BIN"; return 1; }
    [[ "$output" == *"not installed locally"* ]] || { echo "$output"; rm -rf "$BIN"; return 1; }
    # 로컬 node_modules/.bin 에 있으면 그것을 쓴다
    mkdir -p node_modules/.bin
    printf '#!/bin/sh\necho "local-biome $*" >> "%s/called"\n' "$BIN" > node_modules/.bin/biome; chmod +x node_modules/.bin/biome
    run env PATH="$BIN:/usr/bin:/bin" bash "$HOOKS_DIR/auto-format.sh" <<< "$(jq -nc --arg f "$PWD/a.ts" '{tool_input:{file_path:$f}}')"
    grep -q '^local-biome format --write' "$BIN/called"
    run grep -q '^bunx' "$BIN/called"
    rm -rf "$BIN"
    [ "$status" -ne 0 ]
}

# ─── 차단 로그 (2026-10-12 — 자기 사용으로 효과를 숫자로 재기 위함) ────────
# 위치: <git common dir>/claude/blocks.jsonl — 한 줄에 {ts, reason, command} 하나
# 관측 장치라 fail-open: 로그를 못 써도 차단 판정은 그대로다

@test "block-log: 영수증 없는 push 차단은 blocks.jsonl 에 한 줄을 남긴다" {
    git checkout -q -b feat/x
    printf 'untested\n' > README.md
    git add README.md && git commit -q -m "untested change"
    run_guard 'git push origin feat/x'; [ "$status" -eq 2 ]
    LOG="$REPO/.git/claude/blocks.jsonl"
    [ "$(wc -l < "$LOG")" -eq 1 ]
    jq -e '.reason | test("no passing test receipt")' "$LOG"
    jq -e '.command == "git push origin feat/x"' "$LOG"
    jq -e '.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")' "$LOG"
}

@test "block-log: 허용된 명령은 아무것도 남기지 않는다" {
    run_guard 'git status'; [ "$status" -eq 0 ]
    [ ! -e "$REPO/.git/claude/blocks.jsonl" ]
}

@test "block-log: 로그를 쓸 수 없어도 차단 판정은 바뀌지 않는다 (fail-open)" {
    mkdir -p "$REPO/.git/claude"
    mkdir "$REPO/.git/claude/blocks.jsonl"   # 파일 자리에 디렉터리 — 쓰기 실패 유도
    run_guard 'rm -rf /'; [ "$status" -eq 2 ]
    [[ "$output" == *"Blocked:"* ]]
}

@test "block-log: 긴 명령은 200자로 잘라 남긴다" {
    long="echo $(printf 'a%.0s' {1..300}) > .env"
    run_guard "$long"; [ "$status" -eq 2 ]
    jq -e '.command | length <= 200' "$REPO/.git/claude/blocks.jsonl"
}

# ─── 보호 경로 오탐 (2026-10-12 oseyo 설치 중 실측 2건) ─────────────────────
# 내용을 바꾸지 않는 git check-ignore · git add 는 허용, 내용·모드를 바꾸는 것은 계속 차단

@test "guard: 보호 경로를 이름만 참조하는 git check-ignore · git add 는 허용" {
    run_guard 'git check-ignore -v .claude/settings.local.json'; [ "$status" -eq 0 ]
    run_guard 'git add .claude/hooks .claude/settings.json';     [ "$status" -eq 0 ]
    run_guard 'git add -- .claude/hooks/pre-tool-use-guard.sh';  [ "$status" -eq 0 ]
}

@test "guard: 보호 경로의 내용·실행 비트를 바꾸는 git 명령은 계속 차단" {
    for c in 'git add --chmod=-x .claude/hooks/pre-tool-use-guard.sh' \
             'git checkout -- .claude/hooks/pre-tool-use-guard.sh' \
             'git restore .claude/settings.json' \
             'git rm .claude/hooks/pre-tool-use-guard.sh'; do
        run_guard "$c"; [ "$status" -eq 2 ] || { echo "not blocked: $c"; return 1; }
    done
}
