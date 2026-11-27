#!/usr/bin/env bats
# shellcheck shell=bash
# 가드(pre-tool-use-guard.sh) 계약 — 스크립트 파일 실행 · ap:* 라벨 (2026-11-03)
#   - `bash 파일` · `./파일` · `source 파일` 로 실행하는 셸 스크립트는 내용을 명령처럼 같은 규칙으로 판정한다
#     (main push 차단 · 영수증 게이트 · 위임 실행). 중첩 스크립트도 따라간다(깊이 상한)
#   - python · node 같은 인터프리터 파일은 내용에 git push · gh pr create · /pulls · ap:* 라벨이 보이면 차단(위임 실행)
#   - ap:* 라벨(판정 채점 · 심각 결함)은 사람만 단다 — gh 로 달기 · 떼기 · 라벨 자체 수정·삭제 ·
#     이름 없이 라벨을 지우는 쓰기(목록 교체 PUT · 전부 삭제 · 이슈 PATCH labels · GraphQL 라벨 변경)를 막는다
#   - 정적 검사의 한계: 실행 중에 만들어지는 문자열(조각을 이어 붙인 명령)은 보지 못한다 — 서버 기록 쪽(signals.sh)이 최종 근거

load 'helpers'

setup() {
    REPO="$(make_git_repo)"
    export CLAUDE_PROJECT_DIR="$REPO"
    export TEST_RECEIPT_REQUIRED=1
    unset TEST_CMD
    cd "$REPO" || return 1
    S="$(mktemp -d)"
}

teardown() {
    rm -rf "$REPO" "$S"
}

run_guard() { run bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "$1")"; }
script() {  # $1 파일 이름 · 나머지 줄 → 실행 가능한 셸 스크립트
    local f="$S/$1"
    shift
    { echo '#!/bin/bash'; printf '%s\n' "$@"; } > "$f"
    chmod +x "$f"
    echo "$f"
}

# ─── 스크립트 파일 ────────────────────────────────────────────────────────

@test "script: main 으로 push 하는 스크립트는 bash · sh · ./ · source · . 어느 형태로 실행해도 차단" {
    f="$(script a.sh 'git push origin main')"
    for c in "bash $f" "sh $f" "$f" "source $f" ". $f" "bash -x $f" "timeout 60 bash $f"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
        [[ "$output" == *"main"* ]] || { echo "이유가 다름: $c → $output"; return 1; }
    done
}

@test "script: 상대 경로 스크립트는 cwd 기준으로 찾는다" {
    mkdir -p "$REPO/scripts"
    printf '#!/bin/bash\ngit push --force origin feat/x\n' > "$REPO/scripts/p.sh"
    run_guard "bash scripts/p.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"force"* ]]
}

@test "script: 안에 든 push 도 영수증 게이트를 똑같이 탄다 — 영수증 없으면 차단, 있으면 통과" {
    git branch feat/x
    f="$(script p.sh 'git push origin feat/x')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
    [[ "$output" == *"receipt"* ]]
    bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'bats tests/' false)"
    run_guard "bash $f"
    [ "$status" -eq 0 ]
}

@test "script: 다른 저장소로 cd 한 뒤의 push 는 이 세션 저장소에서 ref 를 못 찾아 차단 — 저장소마다 그 저장소 세션에서" {
    f="$(script p.sh 'cd /tmp/other-repo' 'git push -u origin ci/x')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
}

@test "script: gh pr create 가 든 스크립트도 영수증 게이트를 탄다" {
    f="$(script p.sh 'gh pr create --base main --head feat/none --title t --body b')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
}

@test "script: 중첩 — 스크립트가 부르는 스크립트의 push 도 차단 · 자기 자신을 부르는 스크립트도 끝난다" {
    inner="$(script in.sh 'git push origin main')"
    outer="$(script out.sh "bash $inner")"
    run_guard "sh $outer"
    [ "$status" -eq 2 ]
    self="$S/self.sh"
    printf '#!/bin/bash\nbash %s\n' "$self" > "$self"
    run timeout 20 bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "bash $self")"
    [ "$status" -ne 124 ]
}

@test "script: 표준 입력으로 넣는 형태 — bash < 파일 은 본문 판정 · … | bash 는 무엇이 돌지 몰라 차단" {
    f="$(script a.sh 'git push origin main')"
    run_guard "bash < $f"
    [ "$status" -eq 2 ]
    run_guard "cat $f | bash"
    [ "$status" -eq 2 ]
    ok="$(script ok.sh 'echo hi')"
    run_guard "bash < $ok"
    [ "$status" -eq 0 ]
}

@test "script: 본문의 명령 치환은 괄호 안 명령으로 판정 — \$(git push …) 는 차단 · \$(jq … pulls.raw) · 문자열 속 \\\$( 는 통과" {
    f="$(script s.sh 'out="$(git push origin main 2>&1)"')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
    f="$(script b.sh 'out=`git push origin main`')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
    ok="$(script ok.sh 'n="$(jq -r .x "$tmp/pulls.raw")"' 'echo "cannot push \$( here"')"
    run_guard "bash $ok"
    [ "$status" -eq 0 ]
}

@test "script: 스크립트 안의 위임 실행(bash -c · eval) push 는 차단" {
    f="$(script p.sh "bash -c 'git push origin feat/x'")"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
    [[ "$output" == *"indirect"* ]]
}

@test "script: python · node 파일 안의 git push · gh pr create · /pulls 는 위임 실행으로 차단" {
    printf 'import subprocess\nsubprocess.run(["git", "push", "origin", "main"])\n' > "$S/a.py"
    printf 'require("child_process").execSync("gh pr create --fill")\n' > "$S/a.js"
    printf 'import urllib.request\nurllib.request.urlopen("https://api.github.com/repos/o/r/pulls")\n' > "$S/b.py"
    for c in "python3 $S/a.py" "node $S/a.js" "python $S/b.py"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "script: 무해한 스크립트 · 없는 파일 · 주석에만 push 가 있는 스크립트 · 문서를 고치는 python 은 통과" {
    ok="$(script ok.sh 'echo hello' 'ls -la')"
    run_guard "bash $ok"
    [ "$status" -eq 0 ]
    run_guard "bash $S/none.sh"
    [ "$status" -eq 0 ]
    c="$(script c.sh '# this used to push; now it only prints' 'echo done')"
    run_guard "bash $c"
    [ "$status" -eq 0 ]
    printf 'open("CHANGELOG.md").read()\nprint("push 기록 갱신")\n' > "$S/edit.py"
    run_guard "python3 $S/edit.py"
    [ "$status" -eq 0 ]
    # 문서 본문 글자로만 든 git push · gh pr create · /pulls — 프로세스·네트워크 API 가 없으면 실행이 아니다
    printf 's = open("HANDOFF.md").read()\ns += "git push origin main · gh pr create · repos/o/r/pulls"\nopen("HANDOFF.md", "w").write(s)\n' > "$S/doc.py"
    run_guard "python3 $S/doc.py"
    [ "$status" -eq 0 ]
}

@test "script: python 파일 앞쪽의 /pulls 글자가 뒤쪽 subprocess git push 를 가리지 못한다" {
    printf 'doc = "see repos/o/r/pulls"\nimport subprocess\nsubprocess.run(["git", "push", "origin", "main"])\n' > "$S/mix.py"
    run_guard "python3 $S/mix.py"
    [ "$status" -eq 2 ]
}

@test "줄 잇기: 줄 끝 \\ 로 이어 쓴 명령도 한 명령으로 분석한다 (스크립트 · 도구 명령)" {
    git branch feat/x
    bash "$HOOKS_DIR/test-receipt.sh" <<< "$(post_tool_json 'bats tests/' false)"
    run_guard "$(printf 'git push \\\n  origin feat/x')"
    [ "$status" -eq 0 ]
    f="$(script p.sh "git push \\" '  origin main')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
    [[ "$output" == *"main"* ]]
}

# ─── ap:* 라벨 ────────────────────────────────────────────────────────────

@test "ap 라벨: gh pr/issue edit 로 ap:* 를 달거나 떼면 차단 (쉼표 목록 · = 형태 포함)" {
    for c in "gh pr edit 5 --remove-label ap:s1" "gh pr edit 5 --add-label ap:ok" \
             "gh issue edit 5 --remove-label documentation,ap:s0" "gh pr edit 5 --add-label=ap:wrong" \
             "gh -R o/r pr edit 5 --remove-label 'ap:under-tier'"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
        [[ "$output" == *"ap:"* ]] || { echo "이유가 다름: $c → $output"; return 1; }
    done
}

@test "ap 라벨: 라벨 자체를 지우거나 바꾸면 차단 — gh label delete · edit · create" {
    for c in "gh label delete ap:s1 --yes" "gh label edit ap:s0 --name x" "gh label create ap:s1 --force"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "ap 라벨: gh api 쓰기 — 이름을 쓰든(인코딩 포함) 이름 없이 목록을 바꾸든 차단" {
    for c in "gh api -X DELETE repos/o/r/issues/5/labels/ap:s1" \
             "gh api --method DELETE repos/o/r/issues/5/labels/ap%3As1" \
             "gh api repos/o/r/issues/5/labels -f labels[]=ap:s0" \
             "gh api -X PUT repos/o/r/issues/5/labels -f labels[]=documentation" \
             "gh api -X DELETE repos/o/r/issues/5/labels" \
             "gh api -X PATCH repos/o/r/issues/5 -f labels[]=documentation" \
             "gh api -X PATCH repos/o/r/labels/ap:s1 -f new_name=x" \
             "gh api graphql -f query='mutation { clearLabelsFromLabelable(input: {labelableId: \"X\"}) { clientMutationId } }'" \
             "gh api graphql -f query='mutation { removeLabelsFromLabelable(input: {labelableId: \"X\", labelIds: [\"L\"]}) { clientMutationId } }'"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "ap 라벨: 스크립트 안의 ap:* 조작도 차단" {
    f="$(script l.sh 'gh pr edit 5 --remove-label ap:s1')"
    run_guard "bash $f"
    [ "$status" -eq 2 ]
}

@test "ap 라벨: 다른 라벨 달기 · 라벨 읽기 · autopilot:* 이름은 통과 (재판정용 documentation 라벨)" {
    for c in "gh pr edit 5 --add-label documentation" \
             "gh api repos/o/r/issues/5/labels -f labels[]=documentation" \
             "gh api repos/o/r/issues/5/labels" "gh api repos/o/r/labels/ap:s1" \
             "gh label list" "gh pr view 5 --json labels" \
             "gh pr list --label autopilot:pass"; do
        run_guard "$c"
        [ "$status" -eq 0 ] || { echo "막힘: $c → $output"; return 1; }
    done
}

# ─── 적대적 리뷰(2026-11-03, Claude Opus) 반영 ─────────────────────────────

@test "리뷰: 셸 예약어 뒤의 명령도 판정 — if/then · { } · ( ) · for/do · while · ! · case · 함수 정의" {
    for body in 'if true; then git push origin main; fi' '{ git push origin main; }' '(git push origin main)' \
                'for i in 1; do git push origin main; done' 'while false; do git push origin main; done' \
                '! git push origin main' 'case x in x) git push origin main;; esac' 'f() { git push origin main; }; f' \
                'if true; then gh pr edit 1 --add-label ap:ok; fi'; do
        f="$(script r.sh "$body")"
        run_guard "bash $f"
        [ "$status" -eq 2 ] || { echo "통과됨: $body"; return 1; }
    done
    # 도구 명령으로 직접 쳐도 같다
    run_guard 'if true; then git push origin main; fi'
    [ "$status" -eq 2 ]
}

@test "리뷰: python 이 프로세스로 gh api …/pulls 를 부르면 차단 · 언어 파일의 ap:* 라벨 조작도 차단" {
    printf "import subprocess\nsubprocess.run(['gh', 'api', 'repos/o/r/pulls', '-f', 'title=x'])\n" > "$S/g.py"
    run_guard "python3 $S/g.py"
    [ "$status" -eq 2 ]
    printf "import subprocess\nsubprocess.run(['gh', 'pr', 'edit', '5', '--remove-label', 'ap:s1'])\n" > "$S/l.py"
    run_guard "python3 $S/l.py"
    [ "$status" -eq 2 ]
}

@test "리뷰: 프로세스 치환 bash <(…) · source <(…) · 0< 리다이렉션 · env -i 래퍼도 따라간다" {
    f="$(script a.sh 'git push origin main')"
    for c in "bash <(cat $f)" "source <(cat $f)" "bash 0< $f" "env -i bash $f" "env -i FOO=1 bash $f"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "리뷰: gh pr/issue create 의 --label · -l 에 ap:* 를 넣으면 차단" {
    for c in "gh pr create --label ap:ok --title x --body y" "gh issue create -l ap:s0 --title x --body y" \
             "gh pr create --label=documentation,ap:wrong --title x --body y"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "리뷰: gh api 쓰기의 --input 파일 · -F k=@파일 내용도 본다" {
    printf '{"labels": ["ap:s1"]}\n' > "$S/labels.json"
    printf 'mutation { clearLabelsFromLabelable(input: {labelableId: "X"}) { clientMutationId } }\n' > "$S/m.graphql"
    for c in "gh api -X PUT repos/o/r/issues/5/labels --input $S/labels.json" "gh api repos/o/r/issues/5/labels --input $S/labels.json" \
             "gh api graphql -F query=@$S/m.graphql"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "리뷰 오탐: 1MB 넘는 설치 스크립트 · bats 파일 직접 실행 · 분석기 자신 · shebang 없는 무해한 파일은 통과" {
    { echo '#!/bin/sh'; echo 'echo installing'; head -c 2000000 /dev/zero | tr '\0' 'x'; echo; } > "$S/Miniconda3-installer.sh"
    run_guard "bash $S/Miniconda3-installer.sh -b"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    printf '#!/usr/bin/env bats\n@test "x" {\n  run git push origin feat/none\n}\n' > "$S/t.bats"
    chmod +x "$S/t.bats"
    run_guard "$S/t.bats"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    run_guard "python3 $HOOKS_DIR/hooklib.py analyze-guard"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    printf 'echo hi\n' > "$S/nosb.sh"
    chmod +x "$S/nosb.sh"
    run_guard "$S/nosb.sh"
    [ "$status" -eq 0 ]
}

@test "리뷰: 1MB 넘는 스크립트도 push 단어가 있으면 차단 · shebang 없는 실행 파일도 셸로 본다" {
    { echo '#!/bin/sh'; head -c 1100000 /dev/zero | tr '\0' 'x'; echo; echo 'git push origin main'; } > "$S/big.sh"
    run_guard "bash $S/big.sh"
    [ "$status" -eq 2 ]
    printf 'git push origin main\n' > "$S/nosb2.sh"
    chmod +x "$S/nosb2.sh"
    run_guard "$S/nosb2.sh"
    [ "$status" -eq 2 ]
}

@test "리뷰: FIFO · 디렉터리 · 장치로 리다이렉션해도 멈추지 않고 끝난다" {
    mkfifo "$S/fifo"
    run timeout 10 bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "bash < $S/fifo")"
    [ "$status" -ne 124 ]
    run timeout 10 bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "python3 < $S/fifo")"
    [ "$status" -ne 124 ]
}

@test "리뷰: 같은 스크립트를 수백 번 부르는 중첩도 빠르게 끝난다 (파일별 결과 재사용)" {
    leaf="$(script leaf.sh 'echo leaf')"
    mid="$S/mid.sh"; top="$S/top.sh"
    { echo '#!/bin/bash'; for _ in $(seq 200); do echo "bash $leaf"; done; } > "$mid"
    { echo '#!/bin/bash'; for _ in $(seq 200); do echo "bash $mid"; done; } > "$top"
    run timeout 10 bash "$HOOKS_DIR/pre-tool-use-guard.sh" <<< "$(pre_tool_json "bash $top")"
    [ "$status" -eq 0 ]
}

# ─── 재검증(2026-11-03, Claude Opus) 반영 ─────────────────────────────────

@test "재검증: 언어 파일의 f-string · 백틱 템플릿 · 변수 낀 리스트 · raw 문자열 · 변수에 담은 명령도 차단" {
    printf 'import subprocess\nb = "main"\nsubprocess.run(f"git push origin {b}", shell=True)\n' > "$S/n1.py"
    printf 'const { execSync } = require("child_process")\nexecSync(`git push origin main`)\n' > "$S/n2.js"
    printf 'import subprocess\nrepo = "."\nsubprocess.run(["git", "-C", repo, "push", "origin", "main"])\n' > "$S/n3.py"
    printf "import subprocess\nsubprocess.run(r'git push origin main', shell=True)\n" > "$S/n4.py"
    printf 'import subprocess\ncmd = "git push origin main"\nsubprocess.run(cmd, shell=True)\n' > "$S/n5.py"
    for c in "python3 $S/n1.py" "node $S/n2.js" "python3 $S/n3.py" "python3 $S/n4.py" "python3 $S/n5.py"; do
        run_guard "$c"
        [ "$status" -eq 2 ] || { echo "통과됨: $c"; return 1; }
    done
}

@test "재검증: 주석에만 git push 가 있는 언어 파일은 프로세스 API 가 있어도 통과" {
    printf "import subprocess\n# docs: run 'git push origin feat' after this\nsubprocess.run(['ruff', 'format', '.'])\n" > "$S/fp3.py"
    printf "const cp = require('child_process')\n// later: git push origin main\ncp.execSync('npm test')\n" > "$S/fp4.js"
    for c in "python3 $S/fp3.py" "node $S/fp4.js"; do
        run_guard "$c"
        [ "$status" -eq 0 ] || { echo "막힘: $c → $output"; return 1; }
    done
}

@test "재검증: 함수 정의 function f { } · f () { } · coproc 안의 push 도 차단" {
    for body in 'function f { git push origin main; }' 'f () { git push origin main; }' 'coproc git push origin main'; do
        f="$(script fn.sh "$body")"
        run_guard "bash $f"
        [ "$status" -eq 2 ] || { echo "통과됨: $body"; return 1; }
    done
}

@test "재검증: 깊이 제한 결과는 재사용하지 않는다 — 얕은 곳에서 다시 만난 무해한 스크립트는 통과" {
    leaf="$(script leaf.sh 'echo leaf')"
    d3="$(script d3.sh "bash $leaf")"
    d2="$(script d2.sh "bash $d3")"
    d1="$(script d1.sh "bash $d2")"
    top="$(script top.sh "bash $d1" "bash $leaf")"
    run_guard "bash $top"
    [ "$status" -eq 2 ]   # 3단계를 넘는 사슬은 볼 수 없어 막는다
    top2="$(script top2.sh "bash $leaf" "bash $d2")"
    run_guard "bash $top2"
    [ "$status" -eq 0 ]
}
