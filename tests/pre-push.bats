#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031
# git pre-push 훅 — Claude Code 훅과 무관하게 git 자체가 영수증을 대조하는 2차 방어

load 'helpers'

setup() {
    REPO="$(make_git_repo)"
    REMOTE="$(mktemp -d)"
    git init -q --bare "$REMOTE"
    git -C "$REPO" remote add origin "$REMOTE"
    # apply.sh 가 배치하는 것과 같은 위치에 훅·라이브러리
    mkdir -p "$REPO/.githooks" "$REPO/.claude/hooks"
    cp "$REPO_ROOT/common/hooks/git/pre-push" "$REPO/.githooks/pre-push"
    cp "$REPO_ROOT/common/hooks/hooklib.py" "$REPO/.claude/hooks/hooklib.py"
    chmod +x "$REPO/.githooks/pre-push"
    git -C "$REPO" add -A && git -C "$REPO" commit -q -m "add hooks"   # 실사용처럼 훅·라이브러리는 커밋된 파일
    git -C "$REPO" config core.hooksPath .githooks
    export CLAUDE_PROJECT_DIR="$REPO"
    unset TEST_RECEIPT_REQUIRED
    cd "$REPO" || return 1
}

teardown() { rm -rf "$REPO" "$REMOTE"; }

receipt_now() { bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'pytest' false)"; }

@test "pre-push: 영수증 없이 브랜치 push 는 git 이 거부한다" {
    git checkout -q -b feat/x
    run git push origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"no passing test receipt"* ]]
}

@test "pre-push: 테스트 통과 트리를 커밋한 상태면 push 가 성공한다" {
    git checkout -q -b feat/x
    receipt_now
    run git push origin feat/x
    [ "$status" -eq 0 ]
}

@test "pre-push: 테스트 후 편집·커밋한 트리는 거부, 다시 테스트하면 통과" {
    git checkout -q -b feat/x
    receipt_now
    printf 'x\n' > x.txt && git add x.txt && git commit -q -m "untested"
    run git push origin feat/x
    [ "$status" -ne 0 ]
    receipt_now
    run git push origin feat/x
    [ "$status" -eq 0 ]
}

@test "pre-push: main 으로의 직접 push 는 영수증이 있어도 거부" {
    receipt_now
    run git push origin main
    [ "$status" -ne 0 ]
    [[ "$output" == *"direct push to main is blocked"* ]]
}

@test "pre-push: 태그 push 와 브랜치 삭제는 영수증 없이 통과" {
    git checkout -q -b feat/x
    receipt_now
    git push -q origin feat/x
    printf 'y\n' > y.txt && git add y.txt && git commit -q -m "more"   # 영수증 없는 트리
    git tag v0.0.1
    run git push origin v0.0.1
    [ "$status" -eq 0 ]
    run git push origin --delete feat/x
    [ "$status" -eq 0 ]
}

@test "pre-push: TEST_RECEIPT_REQUIRED=0 이면 영수증 검사는 생략하되 main 차단은 유지" {
    git checkout -q -b feat/x
    TEST_RECEIPT_REQUIRED=0 run git push origin feat/x
    [ "$status" -eq 0 ]
    TEST_RECEIPT_REQUIRED=0 run git push origin feat/x:main
    [ "$status" -ne 0 ]
}

@test "pre-push: hooklib.py 가 없으면 fail-closed" {
    git checkout -q -b feat/x
    rm "$REPO/.claude/hooks/hooklib.py"
    run git push origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"hooklib.py not found"* ]]
}

# ─── pre-commit 프레임워크 모드 (stages: [pre-push]) — stdin 없이 환경변수로 ref 를 받는다 ───

Z40=0000000000000000000000000000000000000000

run_precommit_mode() {   # $1 local ref  $2 remote ref
    local sha; sha="$(git rev-parse "$1")"
    run env PRE_COMMIT_FROM_REF="$Z40" PRE_COMMIT_TO_REF="$sha" \
        PRE_COMMIT_LOCAL_BRANCH="$1" PRE_COMMIT_REMOTE_BRANCH="$2" PRE_COMMIT_REMOTE_NAME=origin \
        PRE_COMMIT_REMOTE_URL="$REMOTE" bash .githooks/pre-push < /dev/null
}

@test "pre-push(pre-commit 모드): 환경변수 ref 로 main 차단·영수증 검사를 한다" {
    git checkout -q -b feat/x
    run_precommit_mode refs/heads/feat/x refs/heads/feat/x
    [ "$status" -ne 0 ]; [[ "$output" == *"no passing test receipt"* ]]
    receipt_now
    run_precommit_mode refs/heads/feat/x refs/heads/feat/x
    [ "$status" -eq 0 ]
    run_precommit_mode refs/heads/feat/x refs/heads/main
    [ "$status" -ne 0 ]; [[ "$output" == *"direct push to main is blocked"* ]]
}

@test "pre-push(pre-commit 모드): 레거시 이름(PRE_COMMIT_SOURCE)과 TO_REF 없는 전체 push(LOCAL_BRANCH 만)도 처리한다" {
    git checkout -q -b feat/x
    sha="$(git rev-parse HEAD)"
    run env PRE_COMMIT_ORIGIN="$Z40" PRE_COMMIT_SOURCE="$sha" \
        PRE_COMMIT_LOCAL_BRANCH=refs/heads/feat/x PRE_COMMIT_REMOTE_BRANCH=refs/heads/feat/x bash .githooks/pre-push < /dev/null
    [ "$status" -ne 0 ]; [[ "$output" == *"no passing test receipt"* ]]
    # all_files 경로(루트 커밋부터 새로 push): from/to ref 없이 브랜치 이름만 온다
    run env PRE_COMMIT_LOCAL_BRANCH=refs/heads/feat/x PRE_COMMIT_REMOTE_BRANCH=refs/heads/master \
        PRE_COMMIT_REMOTE_NAME=origin PRE_COMMIT_REMOTE_URL="$REMOTE" bash .githooks/pre-push < /dev/null
    [ "$status" -ne 0 ]; [[ "$output" == *"direct push to master is blocked"* ]]
    receipt_now
    run env PRE_COMMIT_LOCAL_BRANCH=refs/heads/feat/x PRE_COMMIT_REMOTE_BRANCH=refs/heads/feat/x \
        PRE_COMMIT_REMOTE_NAME=origin PRE_COMMIT_REMOTE_URL="$REMOTE" bash .githooks/pre-push < /dev/null
    [ "$status" -eq 0 ]
    git tag v1
    run_precommit_mode refs/tags/v1 refs/tags/v1
    [ "$status" -eq 0 ]
}
