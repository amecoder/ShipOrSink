#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  apply.sh — sos 표준(린터·포매터·Claude Code 설정·가이드) 적용 CLI      ║
# ║                                                                        ║
# ║  다른 프로젝트에 sos 플러그인에 들어 있는 품질 표준을 팀 규모에 맞게     ║
# ║  골라서 적용하는 도구. Claude Code 안에서는 /sos:setup 이 이걸 부른다.  ║
# ║                                                                        ║
# ║  사전 요구사항:                                                         ║
# ║    - sos 플러그인 설치 또는 ShipOrSink 저장소 clone                     ║
# ║      (SOS_STANDARDS 값 구하는 법: 이 폴더의 README.md 「설치」)         ║
# ║    - bash, jq (Claude Code Hooks에 필요)                               ║
# ║                                                                        ║
# ║  기본 사용법:                                                           ║
# ║    cd /path/to/my-project                                              ║
# ║    bash "$SOS_STANDARDS/apply.sh"                    # 대화형 (레벨 선택)║
# ║    bash "$SOS_STANDARDS/apply.sh" --level slim       # 1~3명 소규모 팀  ║
# ║    bash "$SOS_STANDARDS/apply.sh" --level standard   # 4~10명 팀        ║
# ║    bash "$SOS_STANDARDS/apply.sh" --level full       # 11~30명 팀       ║
# ║    bash "$SOS_STANDARDS/apply.sh" --level enterprise # 30명+ 대규모     ║
# ║                                                                        ║
# ║  선택적 적용:                                                           ║
# ║    bash apply.sh --only rules                        # Rules만          ║
# ║    bash apply.sh --only rules --pick "docker,k8s"    # 특정 Rules만     ║
# ║    bash apply.sh --only hooks                        # Hooks만          ║
# ║    bash apply.sh --only security                     # 보안 템플릿만    ║
# ║    bash apply.sh --only github                       # GitHub 협업 인프라 ║
# ║    bash apply.sh --only guides --pick "rest-api"     # 특정 가이드만    ║
# ║                                                                        ║
# ║  자세한 도움말: bash apply.sh --help                                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PWD}"
LEVEL=""
LANG_OVERRIDE=""
ONLY=""
PICK=""
INCLUDE_DOCS=false
UPGRADE=false
DRY_RUN=false
ASSUME_YES=false   # --yes: 프롬프트 없이 기본값으로 진행 (로컬에서 고친 파일은 덮어쓰지 않는다)
MODE=""            # --check | --diff: 적용 기록(.dev-standards.manifest) 대비 상태만 보고

# ─── Colors & Formatting ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}\n"; }

# ─── Help: 상세 도움말 ──────────────────────────────────────────────────
show_help() {
    cat << 'HELPEOF'

╔══════════════════════════════════════════════════════════════╗
║              sos 표준 apply.sh — 도움말                     ║
╚══════════════════════════════════════════════════════════════╝

사용법:
  bash "$SOS_STANDARDS/apply.sh" [옵션]

옵션:
  --level <레벨>     팀 규모별 적용 레벨 (아래 상세 설명 참고)
  --lang <언어>      언어 지정 (자동 감지됨, 수동 override)
                     가능한 값: python, kotlin-spring, java-spring,
                     typescript-react, go, rust, flutter-dart, swift,
                     csharp-dotnet, ruby-rails
  --target <경로>    대상 프로젝트 경로 (기본: 현재 디렉토리)
  --only <컴포넌트>  특정 컴포넌트만 적용
                     가능한 값: rules, hooks, settings, templates, security, guides, lang
  --pick <항목들>    쉼표로 구분한 특정 항목만 적용 (--only와 함께 사용)
  --include-docs     가이드 문서를 프로젝트 docs/에 복사
  --upgrade          기존 레벨에서 상위 레벨의 추가 항목만 적용
  --yes, -y          프롬프트 없이 기본값으로 진행 (CI·일괄 갱신용).
                     원본이 바뀌었고 로컬 수정이 없는 파일은 자동 갱신, 로컬에서 고친 파일은 유지
  --check            적용 기록(.dev-standards.manifest) 대비 상태 보고 (OK/OUTDATED/MODIFIED/MISSING)
                     OUTDATED·MISSING 이 있으면 exit 1
  --diff             --check 와 같고, 바뀐 파일의 diff 도 출력 (파일은 쓰지 않음)
  --dry-run          실제 파일 변경 없이 어떤 파일이 적용되는지 확인
  --help, -h         이 도움말 표시

HELPEOF

    # the color variables hold '\033[..m' text (for echo -e); a heredoc does not interpret it — printf %b does
    printf '%b\n' "$(cat << EOF

${BOLD}═══ 레벨별 상세 설명 ═══${NC}

${GREEN}${BOLD}slim${NC} ${DIM}(1~3명 소규모 팀)${NC}
  적용 시간: 약 10분 | 오버헤드: 0 (전부 자동화)

  이런 팀에게 적합:
    - 스타트업 초기, 사이드 프로젝트, 소규모 팀
    - "문서 읽을 시간 없다, 자동으로 해줘"

  적용되는 것:
    ${GREEN}+${NC} .claude/rules/       PRD/SPEC/TDD/Refactoring/품질/보안 + 언어별 규칙
    ${GREEN}+${NC} .claude/hooks/       자동 포맷팅 + 위험 명령 차단 (2개)
    ${GREEN}+${NC} .claude/settings.json 팀 공유 권한 설정
    ${GREEN}+${NC} .gitignore           공통 무시 패턴 추가
    ${GREEN}+${NC} 언어 린터/포매터     bootstrap.sh로 설정 복사

  적용되지 않는 것:
    ${DIM}- PR 템플릿, 코드 리뷰 체크리스트 (3명이면 구두로 충분)${NC}
    ${DIM}- 가이드 문서 (자동화가 대신 강제)${NC}
    ${DIM}- Design Doc, SLO, MSA 등 (불필요)${NC}

${YELLOW}${BOLD}standard${NC} ${DIM}(4~10명 팀)${NC}
  적용 시간: 약 30분 | 오버헤드: PR당 5분 (체크리스트)

  이런 팀에게 적합:
    - 프로덕트가 성장 중, 코드 리뷰 프로세스 필요
    - "기본적인 규칙은 문서화하고 싶다"

  Slim의 모든 것 + :
    ${GREEN}+${NC} .github/PR_TEMPLATE   PR 생성 시 자동 체크리스트
    ${GREEN}+${NC} .github/ 협업 인프라  이슈 폼(AI Task/Bug/Feature), 라벨, 브랜치 ruleset,
                          PR 정책 검사(pr-policy), 보안 게이트(security-review) 워크플로우
    ${GREEN}+${NC} 코드 리뷰 체크리스트  MUST/SHOULD/COULD 심각도
    ${GREEN}+${NC} ADR 템플릿            큰 기술 결정 기록
    ${GREEN}+${NC} .claude/rules/ +22    아키텍처, DDD, Layered, API Contract, Privacy, RDBMS/NoSQL/DB Governance,
                          Multi-Agent, Context Engineering, Plan Mode, AI Eval 추가
    ${GREEN}+${NC} 가이드 5개            코딩 스타일, Git 컨벤션, 시큐어 코딩,
                          Context Engineering, Multi-Agent Workflow
                          (--include-docs 시)

${BLUE}${BOLD}full${NC} ${DIM}(11~30명 팀)${NC}
  적용 시간: 약 1시간 | 팀 온보딩 포함

  이런 팀에게 적합:
    - 여러 팀/스쿼드, API 설계 표준 필요
    - SLO 기반 운영, 배포 전략 필요
    - "빅테크 수준의 프로세스를 도입하고 싶다"

  Standard의 모든 것 + :
    ${GREEN}+${NC} Design Doc 템플릿     대규모 변경 전 설계 합의
    ${GREEN}+${NC} CODEOWNERS            팀별 코드 소유권
    ${GREEN}+${NC} .claude/rules/ +7     Docker, GitHub Actions, OTel, EDD, Distributed SQL, Multi-Tenancy, Cost Governance
    ${GREEN}+${NC} 가이드 17개           REST API, 에러 핸들링, 성능, SLO,
                          배포 전략, Design Doc, 인시던트, 데이터 모델링,
                          분산 SQL, AI 코드 리뷰, Multi-Agent, Eval, Context

${RED}${BOLD}enterprise${NC} ${DIM}(30명+ 대규모)${NC}
  적용 시간: 약 반나절 | 조직 차원 도입

  이런 팀에게 적합:
    - 마이크로서비스 아키텍처, 분산 시스템
    - SRE 팀 존재, 온콜 로테이션 운영
    - "Google/Netflix/Stripe 수준의 엔지니어링 문화"

  Full의 모든 것 + :
    ${GREEN}+${NC} .claude/rules/ 전체   모든 Rules (k8s, terraform 등)
    ${GREEN}+${NC} docs/guides 전체 48개 MSA, Kafka, Saga, Gateway, gRPC,
                          Contract Test, Load Test, Chaos Engineering,
                          Feature Flag, 위협 모델링, 기술 부채 관리,
                          온콜, 데이터 모델링, TiDB, 캐싱, 온보딩 등

${BOLD}═══ 컴포넌트 설명 (--only 옵션) ═══${NC}

  ${BOLD}rules${NC}      Claude Code가 코드 작성 시 참조하는 규칙 파일
             .claude/rules/ 디렉토리에 복사됨
             paths 패턴으로 언어/파일별 자동 활성화
             예: python.md는 *.py 편집 시에만 로드

  ${BOLD}hooks${NC}      Claude Code의 자동화 스크립트 (5개 — python3 필요)
             auto-format.sh: 파일 저장 시 린터/포매터 자동 실행
             pre-tool-use-guard.sh: rm -rf, force push 등 위험 명령 차단
                                    + 테스트 영수증 없는 git push / gh pr create 차단
             test-receipt.sh: 테스트 명령이 exit 0 이면 작업 트리 해시를 영수증으로 기록
             receipt-lib.sh: 위 두 훅의 공용 함수 · hooklib.py: 명령 토큰 분석 (정규식 우회 방지)
             .githooks/pre-push: git 자체의 2차 영수증 대조 (pre-commit 의 pre-push 단계로 활성화)

  ${BOLD}skills${NC}     워크플로우 스킬 5종 (.claude/skills/<name>/SKILL.md)
             refactoring · vibe-to-production · ai-review-loop · ai-task-spec · plan-mode-workflow
             상시 로드 대신 필요할 때 /<name> — 요약은 AGENTS.md 템플릿에 포함

  ${BOLD}settings${NC}   Claude Code 팀 공유 설정 (.claude/settings.json)
             allow/deny 권한, hooks 등록, MCP 서버 설정

  ${BOLD}templates${NC}  PR, 코드 리뷰, ADR, PRD, Feature Spec, AI 작업 명세,
             DoD, Project Memory, Refactoring, AI 리뷰, DB/API/운영 템플릿

  ${BOLD}security${NC}   Dependabot, Renovate, Gitleaks, detect-secrets 템플릿

  ${BOLD}github${NC}     GitHub 협업 인프라 (.github/)
             이슈 폼 3종 + config, 라벨 정의(labels.json), 브랜치 ruleset(JSON),
             PR 정책 검사 워크플로우(pr-checks.yml + pr-policy.sh),
             보안 게이트 워크플로우(security-review.yml), 설정 반영 스크립트
             --pick: issue-templates, labels, ruleset | ruleset-solo, pr-checks, security-review, ai-ready-guard
             ruleset(팀용: 승인 1 + CODEOWNERS) 는 1인 저장소에서 머지를 영원히 막는다 → ruleset-solo

  ${BOLD}guides${NC}     가이드 문서 (docs/guides/에 복사)
             --pick으로 특정 가이드만 선택 가능

  ${BOLD}lang${NC}       언어별 린터/포매터/테스트 설정 (해당 언어 bootstrap.sh 실행)
  ${BOLD}meetings${NC}   회의록 관리 스캐폴드 (meetings/ 디렉토리 + 용어집 + 템플릿)

${BOLD}═══ 사용 예시 ═══${NC}

  # 소규모 팀, Python 프로젝트
  ${DIM}$ cd my-python-api${NC}
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --level slim${NC}

  # 중규모 팀, TypeScript 프로젝트
  ${DIM}$ cd my-nextjs-app${NC}
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --level standard --lang typescript-react${NC}

  # Docker + K8s + Terraform Rules만 추가 (인프라 엔지니어)
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --only rules --pick "docker,kubernetes,terraform"${NC}

  # REST API 가이드만 복사
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --only guides --pick "rest-api-design"${NC}

  # 회의록 스캐폴드 (meetings/ 디렉토리 + 용어집 + 템플릿)
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --only meetings${NC}

  # Hooks만 추가 (이미 린터 설정이 있는 프로젝트)
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --only hooks${NC}

  # GitHub 협업 인프라만 (이슈 폼, 라벨, ruleset, PR 체크) → 이후 설정 반영
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --only github${NC}
  ${DIM}$ bash .github/scripts/apply-github-settings.sh${NC}

  # 적용 전 미리보기 (파일 변경 없음)
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --level full --dry-run${NC}

  # 가이드 문서를 프로젝트에 포함하고 싶을 때
  ${DIM}$ bash "\$SOS_STANDARDS/apply.sh" --level standard --include-docs${NC}

${BOLD}═══ 적용 가능한 Rules 목록 (--pick) ═══${NC}

  ${GREEN}언어별${NC}      python, kotlin, java, typescript, go, rust, flutter, swift
  ${GREEN}인프라${NC}      docker, kubernetes, terraform, github-actions
  ${GREEN}데이터${NC}      sql, rdbms, nosql, database-governance, distributed-sql
  ${GREEN}도구${NC}        opentelemetry
  ${GREEN}설계${NC}        oop, functional, coding-convention, scaffolding, git-workflow, tdd
  ${GREEN}공통${NC}        security, testing, definition-of-done,
              project-memory, product-requirements,
              multi-agent-orchestration, context-engineering,
              ai-eval-harness, agent-tooling,
              (refactoring · ai-task-spec · ai-review-loop · plan-mode-workflow · vibe-to-production 은 --only skills)
              domain-driven-design, event-driven-design, layered-architecture,
              hexagonal-architecture, modular-monolith, architecture-fitness,
              cqrs-event-sourcing, trunk-based-release, llmops-promptops,
              product-analytics, compliance-audit,
              api-contracts, privacy-data-governance, multi-tenancy,
              cost-governance

${BOLD}═══ 적용 가능한 템플릿 목록 (--pick) ═══${NC}

  ${GREEN}협업${NC}        pr, code-review, adr, design-doc, codeowners,
              contributing, security-policy, license-review, agents
  ${GREEN}AI 개발${NC}     prd, feature-spec, ai-task-spec, definition-of-done,
              project-memory, refactoring-plan, ai-review, claude-md, gemini-md,
              gemini-settings, handoff, codex-progress, subagent-spec,
              adversarial-review, ai-eval-harness
  ${GREEN}아키텍처${NC}    domain-model, layered-architecture, hexagonal-architecture,
              modular-monolith, architecture-fitness, cqrs-decision,
              event-contract, api-change, openapi, asyncapi
  ${GREEN}데이터/운영${NC} database-decision, database-selection, rdbms-schema-change,
              nosql-adoption, new-database, distributed-sql-readiness,
              data-retention, pii-classification, tenant-isolation,
              runbook, incident-postmortem, oncall-handoff,
              ai-cost-budget, cost-review, release-readiness
  ${GREEN}LLMOps${NC}      prompt-change, model-change
  ${GREEN}분석/실험${NC}   tracking-plan, experiment
  ${GREEN}컴플라이언스${NC} access-review, audit-log, vendor-risk

${BOLD}═══ 적용 가능한 가이드 목록 (--pick) ═══${NC}

  ${GREEN}코딩${NC}        coding-style, git-convention, secure-coding
  ${GREEN}아키텍처${NC}    rest-api-design, microservice-architecture,
              event-driven-architecture, api-gateway,
              service-communication, distributed-transaction,
              data-modeling, distributed-sql, tidb-adoption,
              hexagonal-architecture, architecture-fitness-functions,
              modular-monolith
  ${GREEN}품질${NC}        error-handling, performance, caching-strategy
  ${GREEN}SRE${NC}         sli-slo-sla, deployment-strategy, incident-management,
              oncall
  ${GREEN}테스트${NC}      contract-testing, load-testing, chaos-engineering
  ${GREEN}프로세스${NC}    design-doc-process, ai-code-review, tech-debt-management,
              feature-flag, threat-modeling, onboarding,
              trunk-based-release-governance
  ${GREEN}AI 운영${NC}     llmops-promptops
  ${GREEN}분석/실험${NC}   product-analytics-experimentation
  ${GREEN}컴플라이언스${NC} compliance-audit-readiness
  ${GREEN}AI 협업${NC}     multi-agent-workflow, context-engineering,
              eval-driven-development, vibe-coding-to-production
  ${GREEN}기본${NC}        documentation-standards, linting-integration

${BOLD}═══ FAQ ═══${NC}

  ${BOLD}Q: 이미 ESLint/Ruff 설정이 있는 프로젝트에 적용하면?${NC}
  A: 기존 파일이 있으면 diff를 보여주고, 덮어쓸지 선택할 수 있다.
     강제 덮어쓰기는 절대 하지 않는다.

  ${BOLD}Q: 팀이 커져서 레벨을 올리고 싶으면?${NC}
  A: 다시 apply.sh를 더 높은 레벨로 실행하면 된다.
     이미 적용된 파일은 스킵하고 추가 항목만 적용한다.

  ${BOLD}Q: Claude Code 없이 린터/포매터만 쓸 수 있나?${NC}
  A: bash apply.sh --only lang 으로 언어 템플릿만 적용 가능.
     Claude Code Rules/Hooks 없이 린터 설정만 복사된다.

  ${BOLD}Q: 특정 Rule을 커스터마이징하고 싶으면?${NC}
  A: .claude/rules/ 에 복사된 파일을 직접 수정하면 된다.
     sos 표준을 다시 적용해도 수정된 파일은 덮어쓰지 않는다.

EOF
    )"
}

# ─── Args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --level)        LEVEL="$2";         shift 2 ;;
        --lang)         LANG_OVERRIDE="$2"; shift 2 ;;
        --target)       TARGET_DIR="$2";    shift 2 ;;
        --only)         ONLY="$2";          shift 2 ;;
        --pick)         PICK="$2";          shift 2 ;;
        --include-docs) INCLUDE_DOCS=true;  shift ;;
        --upgrade)      UPGRADE=true;       shift ;;
        --yes|-y)       ASSUME_YES=true;    shift ;;
        --check)        MODE="check";       shift ;;
        --diff)         MODE="diff";        shift ;;
        --dry-run)      DRY_RUN=true;       shift ;;
        --help|-h)      show_help;          exit 0 ;;
        *) error "알 수 없는 옵션: $1 (--help로 도움말 확인)"; exit 1 ;;
    esac
done

# ─── Language Detection ──────────────────────────────────────────────────
# 강한 마커(언어 고유 매니페스트)를 먼저 검사하고,
# package.json 같은 약한 마커는 마지막에 둔다.
# 예: Rails 앱에 package.json이 함께 있어도 Gemfile이 먼저 매치되어 ruby-rails로 분류.
detect_language() {
    local dir="$1"
    if   [[ -f "$dir/pyproject.toml" || -f "$dir/setup.py" || -f "$dir/requirements.txt" ]]; then
        echo "python"
    elif [[ -f "$dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$dir/pubspec.yaml" ]] && grep -q "flutter:" "$dir/pubspec.yaml" 2>/dev/null; then
        echo "flutter-dart"
    elif [[ -f "$dir/Package.swift" || -n "$(find "$dir" -maxdepth 1 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) -print -quit 2>/dev/null)" ]]; then
        echo "swift"
    elif [[ -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" || -d "$dir/src/main/kotlin" ]] \
        || grep -qsE 'kotlin\(|org\.jetbrains\.kotlin' "$dir/build.gradle" 2>/dev/null; then
        # Kotlin DSL·Kotlin 소스·Kotlin 플러그인 선언이 있어야 Kotlin. Groovy build.gradle 만 있으면 Java
        echo "kotlin-spring"
    elif [[ -f "$dir/pom.xml" || -f "$dir/build.gradle" || -f "$dir/settings.gradle" ]]; then
        echo "java-spring"
    elif [[ -f "$dir/global.json" || -n "$(find "$dir" -maxdepth 2 \( -name '*.csproj' -o -name '*.sln' -o -name '*.fsproj' \) -print -quit 2>/dev/null)" ]]; then
        echo "csharp-dotnet"
    elif [[ -f "$dir/Gemfile" || -f "$dir/config.ru" || -f "$dir/Rakefile" ]]; then
        echo "ruby-rails"
    elif [[ -f "$dir/tsconfig.json" || -f "$dir/next.config.js" || -f "$dir/next.config.mjs" || -f "$dir/next.config.ts" || -f "$dir/package.json" ]]; then
        # 약한 마커 — Rails/Django 등 다른 언어가 함께 JS 도구를 쓰는 경우를 위해 마지막에 검사
        echo "typescript-react"
    else
        echo "unknown"
    fi
}

[[ -d "$TARGET_DIR" ]] && TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
TARGET_LANG="${LANG_OVERRIDE:-$(detect_language "$TARGET_DIR")}"

# ─── Safe Copy (덮어쓰기 전 확인) ───────────────────────────────────────
# dry-run 에서는 디렉터리도 만들지 않는다 (미리보기가 흔적을 남기면 안 된다)
ensure_dir() {
    [[ "$DRY_RUN" == true ]] || mkdir -p "$@"
}

# ─── 확인 질문 · 적용 기록(manifest) ─────────────────────────────────────
# confirm "질문" Y|N — --yes 거나 입력이 없으면(EOF·파이프) 기본값을 쓴다. 비대화형 실행이 read 실패로 죽지 않게 한다.
confirm() {
    local question="$1" default="$2" answer=""
    if [[ "$ASSUME_YES" == true ]]; then
        [[ "$default" == "Y" ]]
        return
    fi
    if [[ "$default" == "Y" ]]; then echo -n "$question (Y/n): "; else echo -n "$question (y/N): "; fi
    read -r answer || answer=""
    [[ -z "$answer" ]] && answer="$default"
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# 적용 기록: 대상 프로젝트의 .dev-standards.manifest — 한 줄 = "대상 상대경로<TAB>원본 spec<TAB>설치 당시 sha256".
# 원본 spec 은 이 저장소 기준 상대경로이고, "#변형" 을 붙이면 render_source 가 같은 변형을 다시 만든다.
# 이 기록으로 "원본이 바뀌었고 로컬 수정이 없는 파일"(자동 갱신 가능)과 "로컬에서 고친 파일"(유지)을 구분한다.
MANIFEST_NAME=".dev-standards.manifest"
manifest_path() { printf '%s/%s' "$TARGET_DIR" "$MANIFEST_NAME"; }

sha256_of() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        sha256sum "$1" | cut -d' ' -f1
    fi
}

manifest_get() {
    local m
    m="$(manifest_path)"
    [[ -f "$m" ]] || return 0
    awk -F'\t' -v t="$1" '$1==t{h=$3} END{if (h) print h}' "$m"
}

manifest_set() {
    [[ "$DRY_RUN" == true ]] && return 0
    local m tmp
    m="$(manifest_path)"
    tmp="$m.tmp.$$"
    {
        printf '# sos 표준 적용 기록 — apply.sh --check / --diff 가 읽는다. 직접 고치지 않는다.\n'
        printf '# source_commit=%s\n' "$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        [[ -f "$m" ]] && awk -F'\t' -v t="$1" '!/^#/ && $1!=t' "$m"
        printf '%s\t%s\t%s\n' "$1" "$2" "$3"
    } > "$tmp"
    mv "$tmp" "$m"
}

# render_source <spec> <출력파일> — 원본(과 변형)을 출력파일로 만든다
render_source() {
    local spec="$1" out="$2" path variant=""
    path="${spec%%#*}"
    [[ "$spec" == *"#"* ]] && variant="${spec#*#}"
    [[ -f "$SCRIPT_DIR/$path" ]] || return 1
    case "$variant" in
        "")            cp "$SCRIPT_DIR/$path" "$out" ;;
        no-issue-gate) sed '/<!-- dev-standards:issue-gate:start -->/,/<!-- dev-standards:issue-gate:end -->/d' \
                           "$SCRIPT_DIR/$path" > "$out" ;;
        *)             return 1 ;;
    esac
}

# --check / --diff — 적용 기록의 각 파일을 현재 원본과 비교한다. 파일은 쓰지 않는다.
run_check() {
    local mode="$1" m tmp
    m="$(manifest_path)"
    [[ -f "$m" ]] || { error "적용 기록이 없습니다: $m (apply.sh 로 한 번 적용한 뒤 사용하세요)"; exit 2; }
    tmp="$(mktemp)"
    local ok=0 outdated=0 modified=0 missing=0
    local rel spec recorded dst state cur src_hash
    while IFS=$'\t' read -r rel spec recorded; do
        [[ -z "$rel" || "$rel" == \#* ]] && continue
        if ! render_source "$spec" "$tmp"; then
            warn "원본을 찾을 수 없음 (이름이 바뀌었거나 삭제됨): $spec"
            continue
        fi
        dst="$TARGET_DIR/$rel"
        src_hash="$(sha256_of "$tmp")"
        if [[ ! -f "$dst" ]]; then
            state="MISSING";  missing=$((missing + 1))
        else
            cur="$(sha256_of "$dst")"
            if   [[ "$cur" == "$src_hash" ]]; then state="OK";       ok=$((ok + 1))
            elif [[ "$cur" == "$recorded" ]]; then state="OUTDATED"; outdated=$((outdated + 1))
            else                                   state="MODIFIED"; modified=$((modified + 1))
            fi
        fi
        [[ "$state" == "OK" ]] && continue
        printf '%-9s %s\n' "$state" "$rel"
        if [[ "$mode" == "diff" && -f "$dst" ]]; then
            echo "--- $rel (현재)"
            echo "+++ $spec (원본)"
            diff "$dst" "$tmp" || true
        fi
    done < "$m"
    rm -f "$tmp"
    echo "OK $ok · OUTDATED $outdated · MODIFIED $modified · MISSING $missing"
    if [[ "$mode" == "check" && $((outdated + missing)) -gt 0 ]]; then
        info "갱신: bash $SCRIPT_DIR/apply.sh --yes --target $TARGET_DIR (같은 --level/--only) — 로컬에서 고친 파일은 유지된다"
        exit 1
    fi
    exit 0
}

# safe_copy <원본> <대상> [원본 spec]
#   - 대상이 없으면 만든다
#   - 원본이 바뀌었고 대상이 설치 당시 그대로면(로컬 수정 없음) 자동 갱신한다
#   - 대상을 로컬에서 고쳤으면: --yes/--upgrade 는 유지, 대화형은 묻는다
safe_copy() {
    local src="$1" dst="$2" spec="${3:-}"
    [[ -z "$spec" ]] && spec="${src#"$SCRIPT_DIR"/}"
    local rel="${dst#"$TARGET_DIR"/}"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -f "$dst" ]]; then
            info "[dry-run] 업데이트: $(basename "$dst")"
        else
            info "[dry-run] 생성: $(basename "$dst")"
        fi
        return 0
    fi

    if [[ ! -f "$dst" ]]; then
        ensure_dir "$(dirname "$dst")"
        cp "$src" "$dst"
        manifest_set "$rel" "$spec" "$(sha256_of "$dst")"
        success "생성: $rel"
        return 0
    fi

    if cmp -s "$src" "$dst"; then
        manifest_set "$rel" "$spec" "$(sha256_of "$dst")"
        return 0
    fi

    local recorded current answer=""
    recorded="$(manifest_get "$rel")"
    current="$(sha256_of "$dst")"
    if [[ -n "$recorded" && "$recorded" == "$current" ]]; then
        cp "$src" "$dst"
        manifest_set "$rel" "$spec" "$(sha256_of "$dst")"
        success "갱신 (원본 변경 · 로컬 수정 없음): $rel"
        return 0
    fi

    if [[ "$UPGRADE" == true || "$ASSUME_YES" == true ]]; then
        warn "유지 (로컬에서 수정됨 — 차이는 apply.sh --diff 로 확인): $rel"
        return 0
    fi
    warn "이미 존재하며 내용이 다름: $rel"
    echo -n "  덮어쓰기? (y/N/d=diff 보기): "
    read -r answer || answer=""
    case "$answer" in
        y|Y) cp "$src" "$dst"
             manifest_set "$rel" "$spec" "$(sha256_of "$dst")"
             success "덮어쓰기 완료: $rel" ;;
        d|D) diff "$dst" "$src" || true
             safe_copy "$src" "$dst" "$spec" ;;
        *)   info "스킵: $rel" ;;
    esac
}

safe_copy_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    ensure_dir "$dst_dir"
    for f in "$src_dir"/*; do
        [[ -f "$f" ]] && safe_copy "$f" "$dst_dir/$(basename "$f")"
    done
}

# ─── Component: Rules ────────────────────────────────────────────────────
# Claude Code가 코드 작성 시 참조하는 규칙 파일.
# .claude/rules/ 디렉토리에 복사되며, YAML frontmatter의 paths 패턴에 따라
# 해당 파일 작업 시에만 자동으로 활성화된다.
#
# 레벨별 적용 규칙:
#   slim:       foundation + PRD/SPEC/TDD/refactoring + language + security/testing
#   standard:   slim + architecture/DDD/layered/API/privacy/RDBMS/NoSQL/data governance + AI review loop
#   full:       standard + infra/event/multi-tenancy/cost/distributed data rules
#   enterprise: every rule file
language_rule_for() {
    case "$1" in
        typescript-react|typescript|ts|react) echo "typescript.md" ;;
        kotlin-spring)                        echo "kotlin.md" ;;
        java-spring|spring)                   echo "java.md" ;;
        flutter-dart|flutter|dart)            echo "dart.md" ;;
        csharp-dotnet|dotnet)                 echo "csharp.md" ;;
        ruby-rails|rails)                     echo "ruby.md" ;;
        *)                                    echo "${1%%"-"*}.md" ;;
    esac
}

apply_rules() {
    local level="$1"
    local pick="$2"
    local dst="$TARGET_DIR/.claude/rules"
    ensure_dir "$dst"

    header "Claude Code Rules"

    # Slim: foundation rules + language-specific rule
    local slim_rules=(
        "coding-convention.md"
        "oop.md"
        "functional.md"
        "scaffolding.md"
        "git-workflow.md"
        "product-requirements.md"
        "definition-of-done.md"
        "project-memory.md"
        "context-engineering.md"
        "agent-tooling.md"
        "tdd.md"
        "security.md"
        "testing.md"
    )
    if [[ "$TARGET_LANG" != "unknown" ]]; then
        slim_rules+=("$(language_rule_for "$TARGET_LANG")")
    fi

    # Standard: slim + architecture/design/data basics + release/llmops/analytics governance
    local standard_rules=(
        "${slim_rules[@]}"
        "architecture.md"
        "layered-architecture.md"
        "hexagonal-architecture.md"
        "modular-monolith.md"
        "architecture-fitness.md"
        "domain-driven-design.md"
        "api-contracts.md"
        "design.md"
        "ci-cd.md"
        "sql.md"
        "rdbms.md"
        "nosql.md"
        "database-governance.md"
        "privacy-data-governance.md"
        "trunk-based-release.md"
        "llmops-promptops.md"
        "product-analytics.md"
        "multi-agent-orchestration.md"
        "ai-eval-harness.md"
        "mlops.md"
        "prompt-injection-defense.md"
        "sub-agent-delegation.md"
    )

    # Full: standard + infra, event, tenancy, cost, distributed data, CQRS/ES, compliance
    local full_rules=(
        "${standard_rules[@]}"
        "docker.md"
        "github-actions.md"
        "opentelemetry.md"
        "event-driven-design.md"
        "distributed-sql.md"
        "multi-tenancy.md"
        "cost-governance.md"
        "cqrs-event-sourcing.md"
        "compliance-audit.md"
    )

    # Enterprise: every rule file
    local enterprise_rules=()
    for f in "$SCRIPT_DIR/common/rules/"*.md; do
        enterprise_rules+=("$(basename "$f")")
    done

    local rules_to_apply=()

    if [[ -n "$pick" ]]; then
        # --pick 모드: 사용자가 지정한 규칙만
        IFS=',' read -ra items <<< "$pick"
        for item in "${items[@]}"; do
            item="$(echo "$item" | xargs)"  # trim whitespace
            if [[ -f "$SCRIPT_DIR/common/rules/${item}.md" ]]; then
                rules_to_apply+=("${item}.md")
            elif [[ -f "$SCRIPT_DIR/common/rules/${item}" ]]; then
                rules_to_apply+=("${item}")
            elif [[ -f "$SCRIPT_DIR/common/rules/$(language_rule_for "$item")" ]]; then
                rules_to_apply+=("$(language_rule_for "$item")")   # 언어 이름(flutter, dotnet …)으로 고른 경우
            else
                warn "Rules 파일을 찾을 수 없음: ${item}"
                info "  사용 가능한 Rules: $(find "$SCRIPT_DIR/common/rules/" -name '*.md' | sed 's|.*/||; s/\.md$//' | sort | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
            fi
        done
    else
        case "$level" in
            slim)       rules_to_apply=("${slim_rules[@]}") ;;
            standard)   rules_to_apply=("${standard_rules[@]}") ;;
            full)       rules_to_apply=("${full_rules[@]}") ;;
            enterprise) rules_to_apply=("${enterprise_rules[@]}") ;;
            *)          rules_to_apply=("${slim_rules[@]}") ;;
        esac
    fi

    for rule in "${rules_to_apply[@]}"; do
        if [[ -f "$SCRIPT_DIR/common/rules/$rule" ]]; then
            safe_copy "$SCRIPT_DIR/common/rules/$rule" "$dst/$rule"
        fi
    done

    success "Rules ${#rules_to_apply[@]}개 적용 완료 → .claude/rules/"
}

# ─── Component: Skills ───────────────────────────────────────────────────
# 워크플로우 규칙 5종(리팩터링·프로덕션 승격·AI 리뷰 루프·작업 명세·플랜 모드)은 파일 경로와 무관한
# "언제 무엇을 하라" 규칙이라 상시 로드 대신 스킬로 둔다 — 요약은 AGENTS.md 에, 전문은 필요할 때 /<name> 으로.
apply_skills() {
    local dst="$TARGET_DIR/.claude/skills"

    header "Claude Code Skills"
    local count=0
    for dir in "$SCRIPT_DIR/common/skills/"*/; do
        local name
        name="$(basename "$dir")"
        ensure_dir "$dst/$name"
        safe_copy "$dir/SKILL.md" "$dst/$name/SKILL.md"
        count=$((count + 1))
    done
    success "Skills ${count}개 적용 완료 → .claude/skills/"
}

# ─── Component: Hooks ────────────────────────────────────────────────────
# Claude Code 자동화 스크립트.
#   auto-format.sh: 파일 편집/생성 후 해당 언어의 포매터를 자동 실행
#                   (Python=ruff, Go=gofumpt, TS=prettier, Kotlin=ktlint 등)
#   pre-tool-use-guard.sh: rm -rf, force push, DROP TABLE 등 위험 명령 차단
#                          exit 2로 Claude Code 액션을 중단시킴
apply_hooks() {
    local dst="$TARGET_DIR/.claude/hooks"
    ensure_dir "$dst"

    header "Claude Code Hooks"
    info "auto-format.sh     — 10개 언어 자동 포맷팅 (PostToolUse)"
    info "pre-tool-use-guard — 위험 명령 차단 + 테스트 영수증 없는 push/PR 차단 (PreToolUse)"
    info "test-receipt.sh    — 테스트 명령 exit 0 → 작업 트리 해시 영수증 기록 (PostToolUse)"
    info "receipt-lib.sh     — 영수증 공용 함수 (두 훅이 source)"
    info "hooklib.py         — 명령 토큰 분석·영수증 저장소 (python3 stdlib, 두 훅이 호출)"

    safe_copy "$SCRIPT_DIR/common/hooks/auto-format.sh" "$dst/auto-format.sh"
    safe_copy "$SCRIPT_DIR/common/hooks/pre-tool-use-guard.sh" "$dst/pre-tool-use-guard.sh"
    safe_copy "$SCRIPT_DIR/common/hooks/test-receipt.sh" "$dst/test-receipt.sh"
    safe_copy "$SCRIPT_DIR/common/hooks/receipt-lib.sh" "$dst/receipt-lib.sh"
    safe_copy "$SCRIPT_DIR/common/hooks/hooklib.py" "$dst/hooklib.py"

    # git 자체가 검사하는 2차 방어 — Claude Code 훅을 우회한 push 도 영수증을 대조한다 (활성화는 사람이)
    ensure_dir "$TARGET_DIR/.githooks"
    safe_copy "$SCRIPT_DIR/common/hooks/git/pre-push" "$TARGET_DIR/.githooks/pre-push"

    if [[ "$DRY_RUN" != true ]]; then
        chmod +x "$dst/"*.sh "$dst/"*.py "$TARGET_DIR/.githooks/pre-push" 2>/dev/null
    fi

    success "Hooks 5개 + git pre-push 적용 완료 → .claude/hooks/, .githooks/"
    info "git 2차 방어(pre-push)는 pre-commit 으로 켠다 (core.hooksPath 는 pre-commit·husky 와 서로 꺼 버려 쓰지 않는다):"
    info "  .pre-commit-config.yaml → - repo: local"
    info "                             hooks: [{id: test-receipt-pre-push, name: test receipt, entry: .githooks/pre-push,"
    info "                                      language: script, stages: [pre-push], always_run: true, pass_filenames: false}]"
    info "  그다음: pre-commit install --hook-type pre-commit --hook-type pre-push"
    info "테스트가 없는 저장소는 .claude/settings.json 의 env TEST_RECEIPT_REQUIRED 를 \"0\" 으로 (사람이 결정)"
}

# ─── Component: Settings ─────────────────────────────────────────────────
# Claude Code 팀 공유 설정.
# .claude/settings.json에 복사되며, Git에 커밋하면 팀 전체가 동일한 권한을 공유한다.
# 포함 내용: allow/deny 권한 패턴, hooks 등록, MCP 보안 설정
apply_settings() {
    local dst="$TARGET_DIR/.claude"
    ensure_dir "$dst"

    header "Claude Code Settings"
    local src="$SCRIPT_DIR/common/.claude-settings-team.json" out="$dst/settings.json"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] $( [[ -f "$out" ]] && echo 병합 || echo 생성 ): settings.json"
        return 0
    fi
    if [[ ! -f "$out" ]]; then
        cp "$src" "$out"
        success "생성: .claude/settings.json"
    elif cmp -s "$src" "$out"; then
        info "settings.json 최신"
    elif command -v jq >/dev/null 2>&1; then
        merge_settings "$out" "$src"
    else
        warn "jq 가 없어 settings.json 을 병합하지 못했습니다 — 기존 파일 유지. 원본: $src"
    fi
    info "팀에 맞게 권한을 조정하려면 .claude/settings.json을 편집하세요 (다시 적용해도 병합만 한다)"
}

# merge_settings <대상 settings.json> <원본> — 덮어쓰지 않고 병합한다.
#   permissions.allow/deny: 합집합 (대상 순서 유지 + 원본에만 있는 항목 뒤에 추가)
#   hooks: 이벤트별로 대상 항목 유지 + 대상에 없는 command 를 가진 원본 항목만 추가 (재적용해도 중복 없음)
#   env 와 그 밖의 키: 대상 값 우선, 대상에 없는 키만 원본에서 가져온다
merge_settings() {
    local out="$1" src="$2" tmp
    tmp="$(mktemp)"
    if ! jq -s '
        def union($a; $b): reduce ($b // [])[] as $x (($a // []); if any(.[]; . == $x) then . else . + [$x] end);
        def cmds: [.[]?.hooks[]?.command];
        .[0] as $t | .[1] as $s
        | ($s + $t)
        | .env = (($s.env // {}) + ($t.env // {}))
        | .permissions = (($s.permissions // {}) + ($t.permissions // {}))
        | .permissions.allow = union($t.permissions.allow; $s.permissions.allow)
        | .permissions.deny  = union($t.permissions.deny;  $s.permissions.deny)
        | .hooks = (($t.hooks // {}) as $th | ($s.hooks // {}) as $sh
            | reduce (($th + $sh) | keys[]) as $k ({};
                .[$k] = (($th[$k] // []) as $te | ($te | cmds) as $tc
                    | $te + [($sh[$k] // [])[] | select(([.hooks[]?.command] - $tc) | length > 0)])))
    ' "$out" "$src" > "$tmp"; then
        rm -f "$tmp"
        warn "settings.json 병합 실패 (JSON 이 올바른지 확인) — 기존 파일 유지"
        return 0
    fi
    if cmp -s "$tmp" "$out"; then
        rm -f "$tmp"
        info "settings.json 최신 (병합할 항목 없음)"
    else
        mv "$tmp" "$out"
        success "settings.json 병합 (기존 권한·설정 유지 + 표준 훅·권한 추가)"
    fi
}

# ─── Component: Templates ────────────────────────────────────────────────
# 공용 문서 템플릿.
# 레벨별 적용:
#   standard: PR + 코드 리뷰 + ADR + PRD/SPEC + AI 작업 명세/DoD/Memory/Review 템플릿
#   full:     + Design Doc + CODEOWNERS + architecture/API/privacy/operation/cost templates
apply_templates() {
    local level="$1"
    local pick="${2:-}"

    header "공용 템플릿"

    local github_dir="$TARGET_DIR/.github"
    local copied=0

    copy_template_item() {
        local item="$1"
        case "$item" in
            pr|PR_TEMPLATE|PR_TEMPLATE.md)
                ensure_dir "$github_dir"
                safe_copy "$SCRIPT_DIR/common/templates/PR_TEMPLATE.md" "$github_dir/PULL_REQUEST_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            code-review|CODE_REVIEW_CHECKLIST|CODE_REVIEW_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/CODE_REVIEW_CHECKLIST.md" "$TARGET_DIR/docs/CODE_REVIEW_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            adr|ADR_TEMPLATE|ADR_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/adr"
                safe_copy "$SCRIPT_DIR/common/templates/ADR_TEMPLATE.md" "$TARGET_DIR/docs/adr/TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            design-doc|DESIGN_DOC_TEMPLATE|DESIGN_DOC_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/design-docs"
                safe_copy "$SCRIPT_DIR/common/templates/DESIGN_DOC_TEMPLATE.md" "$TARGET_DIR/docs/design-docs/TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            codeowners|CODEOWNERS)
                ensure_dir "$github_dir"
                safe_copy "$SCRIPT_DIR/common/templates/CODEOWNERS" "$github_dir/CODEOWNERS"
                copied=$((copied + 1))
                ;;
            agents|AGENTS|AGENTS.md|AGENTS_TEMPLATE|AGENTS_TEMPLATE.md)
                # 이슈 기반 자율 작업 규칙(ai-ready 라벨)은 GitHub 이슈로 일을 주는 프로젝트에만 넣는다 (--yes: 넣지 않음)
                if confirm "  AGENTS.md 에 이슈 기반 자율 작업 규칙(ai-ready 라벨 이슈만 무인 실행)을 넣을까요?" N; then
                    safe_copy "$SCRIPT_DIR/common/templates/AGENTS_TEMPLATE.md" "$TARGET_DIR/AGENTS.md"
                else
                    local rendered
                    rendered="$(mktemp)"
                    render_source "common/templates/AGENTS_TEMPLATE.md#no-issue-gate" "$rendered"
                    safe_copy "$rendered" "$TARGET_DIR/AGENTS.md" "common/templates/AGENTS_TEMPLATE.md#no-issue-gate"
                    rm -f "$rendered"
                fi
                copied=$((copied + 1))
                ;;
            claude-md|claude|CLAUDE|CLAUDE.md|CLAUDE_MD_TEMPLATE|CLAUDE_MD_TEMPLATE.md)
                safe_copy "$SCRIPT_DIR/common/templates/CLAUDE_MD_TEMPLATE.md" "$TARGET_DIR/CLAUDE.md"
                copied=$((copied + 1))
                ;;
            gemini-md|gemini|GEMINI|GEMINI.md|GEMINI_MD_TEMPLATE|GEMINI_MD_TEMPLATE.md)
                safe_copy "$SCRIPT_DIR/common/templates/GEMINI_MD_TEMPLATE.md" "$TARGET_DIR/GEMINI.md"
                copied=$((copied + 1))
                ;;
            gemini-settings|GEMINI_SETTINGS|GEMINI_SETTINGS_TEMPLATE|GEMINI_SETTINGS_TEMPLATE.json)
                ensure_dir "$TARGET_DIR/.gemini"
                safe_copy "$SCRIPT_DIR/common/templates/GEMINI_SETTINGS_TEMPLATE.json" "$TARGET_DIR/.gemini/settings.json"
                copied=$((copied + 1))
                ;;
            contributing|CONTRIBUTING|CONTRIBUTING.md|CONTRIBUTING_TEMPLATE|CONTRIBUTING_TEMPLATE.md)
                safe_copy "$SCRIPT_DIR/common/templates/CONTRIBUTING_TEMPLATE.md" "$TARGET_DIR/CONTRIBUTING.md"
                copied=$((copied + 1))
                ;;
            security-policy|SECURITY|SECURITY.md|SECURITY_POLICY|SECURITY_POLICY_TEMPLATE|SECURITY_POLICY_TEMPLATE.md)
                safe_copy "$SCRIPT_DIR/common/templates/SECURITY_POLICY_TEMPLATE.md" "$TARGET_DIR/SECURITY.md"
                copied=$((copied + 1))
                ;;
            license-review|LICENSE_REVIEW_CHECKLIST|LICENSE_REVIEW_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/LICENSE_REVIEW_CHECKLIST.md" "$TARGET_DIR/docs/LICENSE_REVIEW_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            prd|PRD|PRD_TEMPLATE|PRD_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/product"
                safe_copy "$SCRIPT_DIR/common/templates/PRD_TEMPLATE.md" "$TARGET_DIR/docs/product/PRD_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            feature-spec|spec|FEATURE_SPEC|FEATURE_SPEC_TEMPLATE|FEATURE_SPEC_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/specs"
                safe_copy "$SCRIPT_DIR/common/templates/FEATURE_SPEC_TEMPLATE.md" "$TARGET_DIR/docs/specs/FEATURE_SPEC_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            ai-task-spec|AI_TASK_SPEC_TEMPLATE|AI_TASK_SPEC_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/AI_TASK_SPEC_TEMPLATE.md" "$TARGET_DIR/docs/AI_TASK_SPEC.md"
                copied=$((copied + 1))
                ;;
            definition-of-done|dod|DEFINITION_OF_DONE|DEFINITION_OF_DONE.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/DEFINITION_OF_DONE.md" "$TARGET_DIR/docs/DEFINITION_OF_DONE.md"
                copied=$((copied + 1))
                ;;
            project-memory|PROJECT_MEMORY_TEMPLATE|PROJECT_MEMORY_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/PROJECT_MEMORY_TEMPLATE.md" "$TARGET_DIR/docs/PROJECT_MEMORY.md"
                copied=$((copied + 1))
                ;;
            ai-review|AI_REVIEW_CHECKLIST|AI_REVIEW_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/AI_REVIEW_CHECKLIST.md" "$TARGET_DIR/docs/AI_REVIEW_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            handoff|HANDOFF|HANDOFF.md|HANDOFF_TEMPLATE|HANDOFF_TEMPLATE.md)
                safe_copy "$SCRIPT_DIR/common/templates/HANDOFF_TEMPLATE.md" "$TARGET_DIR/HANDOFF.md"
                copied=$((copied + 1))
                ;;
            codex-progress|CODEX_PROGRESS|CODEX_PROGRESS_TEMPLATE|CODEX_PROGRESS_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/.codex"
                safe_copy "$SCRIPT_DIR/common/templates/CODEX_PROGRESS_TEMPLATE.md" "$TARGET_DIR/.codex/progress.md"
                copied=$((copied + 1))
                ;;
            subagent-spec|SUBAGENT_SPEC|SUBAGENT_SPEC_TEMPLATE|SUBAGENT_SPEC_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/agents"
                safe_copy "$SCRIPT_DIR/common/templates/SUBAGENT_SPEC_TEMPLATE.md" "$TARGET_DIR/docs/agents/SUBAGENT_SPEC_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            adversarial-review|ADVERSARIAL_REVIEW|ADVERSARIAL_REVIEW_CHECKLIST|ADVERSARIAL_REVIEW_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/ADVERSARIAL_REVIEW_CHECKLIST.md" "$TARGET_DIR/docs/ADVERSARIAL_REVIEW_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            ai-eval-harness|AI_EVAL_HARNESS|AI_EVAL_HARNESS_TEMPLATE|AI_EVAL_HARNESS_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/evals"
                safe_copy "$SCRIPT_DIR/common/templates/AI_EVAL_HARNESS_TEMPLATE.md" "$TARGET_DIR/docs/evals/AI_EVAL_HARNESS.md"
                copied=$((copied + 1))
                ;;
            refactoring-plan|refactoring|REFACTORING_PLAN|REFACTORING_PLAN.md)
                ensure_dir "$TARGET_DIR/docs"
                safe_copy "$SCRIPT_DIR/common/templates/REFACTORING_PLAN.md" "$TARGET_DIR/docs/REFACTORING_PLAN.md"
                copied=$((copied + 1))
                ;;
            domain-model|domain-model-checklist|DOMAIN_MODEL_CHECKLIST|DOMAIN_MODEL_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/DOMAIN_MODEL_CHECKLIST.md" "$TARGET_DIR/docs/architecture/DOMAIN_MODEL_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            event-contract|event-contract-checklist|EVENT_CONTRACT_CHECKLIST|EVENT_CONTRACT_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/contracts"
                safe_copy "$SCRIPT_DIR/common/templates/EVENT_CONTRACT_CHECKLIST.md" "$TARGET_DIR/docs/contracts/EVENT_CONTRACT_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            layered-architecture|layered-checklist|LAYERED_ARCHITECTURE_CHECKLIST|LAYERED_ARCHITECTURE_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/LAYERED_ARCHITECTURE_CHECKLIST.md" "$TARGET_DIR/docs/architecture/LAYERED_ARCHITECTURE_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            api-change|api-change-checklist|API_CHANGE_CHECKLIST|API_CHANGE_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/contracts"
                safe_copy "$SCRIPT_DIR/common/templates/API_CHANGE_CHECKLIST.md" "$TARGET_DIR/docs/contracts/API_CHANGE_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            openapi|OPENAPI|OPENAPI_TEMPLATE|OPENAPI_TEMPLATE.yaml)
                ensure_dir "$TARGET_DIR/docs/contracts"
                safe_copy "$SCRIPT_DIR/common/templates/OPENAPI_TEMPLATE.yaml" "$TARGET_DIR/docs/contracts/openapi.yaml"
                copied=$((copied + 1))
                ;;
            asyncapi|ASYNCAPI|ASYNCAPI_TEMPLATE|ASYNCAPI_TEMPLATE.yaml)
                ensure_dir "$TARGET_DIR/docs/contracts"
                safe_copy "$SCRIPT_DIR/common/templates/ASYNCAPI_TEMPLATE.yaml" "$TARGET_DIR/docs/contracts/asyncapi.yaml"
                copied=$((copied + 1))
                ;;
            database-decision|database-decision-record|DATABASE_DECISION_RECORD|DATABASE_DECISION_RECORD.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/DATABASE_DECISION_RECORD.md" "$TARGET_DIR/docs/database/DATABASE_DECISION_RECORD.md"
                copied=$((copied + 1))
                ;;
            new-database|new-database-checklist|NEW_DATABASE_ADOPTION_CHECKLIST|NEW_DATABASE_ADOPTION_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/NEW_DATABASE_ADOPTION_CHECKLIST.md" "$TARGET_DIR/docs/database/NEW_DATABASE_ADOPTION_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            distributed-sql-readiness|distributed-sql-checklist|DISTRIBUTED_SQL_READINESS_CHECKLIST|DISTRIBUTED_SQL_READINESS_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/DISTRIBUTED_SQL_READINESS_CHECKLIST.md" "$TARGET_DIR/docs/database/DISTRIBUTED_SQL_READINESS_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            database-selection|database-selection-matrix|DATABASE_SELECTION_MATRIX|DATABASE_SELECTION_MATRIX.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/DATABASE_SELECTION_MATRIX.md" "$TARGET_DIR/docs/database/DATABASE_SELECTION_MATRIX.md"
                copied=$((copied + 1))
                ;;
            rdbms-schema-change|rdbms-schema|RDBMS_SCHEMA_CHANGE_CHECKLIST|RDBMS_SCHEMA_CHANGE_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/RDBMS_SCHEMA_CHANGE_CHECKLIST.md" "$TARGET_DIR/docs/database/RDBMS_SCHEMA_CHANGE_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            nosql-adoption|nosql-checklist|NOSQL_ADOPTION_CHECKLIST|NOSQL_ADOPTION_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/database"
                safe_copy "$SCRIPT_DIR/common/templates/NOSQL_ADOPTION_CHECKLIST.md" "$TARGET_DIR/docs/database/NOSQL_ADOPTION_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            data-retention|DATA_RETENTION_POLICY|DATA_RETENTION_POLICY_TEMPLATE|DATA_RETENTION_POLICY_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/privacy"
                safe_copy "$SCRIPT_DIR/common/templates/DATA_RETENTION_POLICY_TEMPLATE.md" "$TARGET_DIR/docs/privacy/DATA_RETENTION_POLICY.md"
                copied=$((copied + 1))
                ;;
            pii-classification|PII_DATA_CLASSIFICATION|PII_DATA_CLASSIFICATION.md)
                ensure_dir "$TARGET_DIR/docs/privacy"
                safe_copy "$SCRIPT_DIR/common/templates/PII_DATA_CLASSIFICATION.md" "$TARGET_DIR/docs/privacy/PII_DATA_CLASSIFICATION.md"
                copied=$((copied + 1))
                ;;
            tenant-isolation|TENANT_ISOLATION_CHECKLIST|TENANT_ISOLATION_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/security"
                safe_copy "$SCRIPT_DIR/common/templates/TENANT_ISOLATION_CHECKLIST.md" "$TARGET_DIR/docs/security/TENANT_ISOLATION_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            runbook|RUNBOOK|RUNBOOK_TEMPLATE|RUNBOOK_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/runbooks"
                safe_copy "$SCRIPT_DIR/common/templates/RUNBOOK_TEMPLATE.md" "$TARGET_DIR/docs/runbooks/RUNBOOK_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            incident-postmortem|postmortem|INCIDENT_POSTMORTEM|INCIDENT_POSTMORTEM_TEMPLATE|INCIDENT_POSTMORTEM_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/incidents"
                safe_copy "$SCRIPT_DIR/common/templates/INCIDENT_POSTMORTEM_TEMPLATE.md" "$TARGET_DIR/docs/incidents/INCIDENT_POSTMORTEM_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            oncall-handoff|ONCALL_HANDOFF|ONCALL_HANDOFF_TEMPLATE|ONCALL_HANDOFF_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/oncall"
                safe_copy "$SCRIPT_DIR/common/templates/ONCALL_HANDOFF_TEMPLATE.md" "$TARGET_DIR/docs/oncall/ONCALL_HANDOFF_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            ai-cost-budget|AI_COST_BUDGET|AI_COST_BUDGET_TEMPLATE|AI_COST_BUDGET_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/cost"
                safe_copy "$SCRIPT_DIR/common/templates/AI_COST_BUDGET_TEMPLATE.md" "$TARGET_DIR/docs/cost/AI_COST_BUDGET.md"
                copied=$((copied + 1))
                ;;
            cost-review|COST_REVIEW_CHECKLIST|COST_REVIEW_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/cost"
                safe_copy "$SCRIPT_DIR/common/templates/COST_REVIEW_CHECKLIST.md" "$TARGET_DIR/docs/cost/COST_REVIEW_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            hexagonal-architecture|hexagonal|HEXAGONAL_ARCHITECTURE_CHECKLIST|HEXAGONAL_ARCHITECTURE_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/HEXAGONAL_ARCHITECTURE_CHECKLIST.md" "$TARGET_DIR/docs/architecture/HEXAGONAL_ARCHITECTURE_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            architecture-fitness|fitness-functions|ARCHITECTURE_FITNESS_TEMPLATE|ARCHITECTURE_FITNESS_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/ARCHITECTURE_FITNESS_TEMPLATE.md" "$TARGET_DIR/docs/architecture/ARCHITECTURE_FITNESS_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            modular-monolith|module-boundary|MODULAR_MONOLITH_CHECKLIST|MODULAR_MONOLITH_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/MODULAR_MONOLITH_CHECKLIST.md" "$TARGET_DIR/docs/architecture/MODULAR_MONOLITH_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            cqrs-decision|cqrs|event-sourcing|CQRS_DECISION_RECORD|CQRS_DECISION_RECORD.md)
                ensure_dir "$TARGET_DIR/docs/architecture"
                safe_copy "$SCRIPT_DIR/common/templates/CQRS_DECISION_RECORD.md" "$TARGET_DIR/docs/architecture/CQRS_DECISION_RECORD.md"
                copied=$((copied + 1))
                ;;
            release-readiness|release|RELEASE_READINESS_CHECKLIST|RELEASE_READINESS_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/release"
                safe_copy "$SCRIPT_DIR/common/templates/RELEASE_READINESS_CHECKLIST.md" "$TARGET_DIR/docs/release/RELEASE_READINESS_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            prompt-change|PROMPT_CHANGE|PROMPT_CHANGE_TEMPLATE|PROMPT_CHANGE_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/llmops"
                safe_copy "$SCRIPT_DIR/common/templates/PROMPT_CHANGE_TEMPLATE.md" "$TARGET_DIR/docs/llmops/PROMPT_CHANGE_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            model-change|MODEL_CHANGE|MODEL_CHANGE_TEMPLATE|MODEL_CHANGE_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/llmops"
                safe_copy "$SCRIPT_DIR/common/templates/MODEL_CHANGE_TEMPLATE.md" "$TARGET_DIR/docs/llmops/MODEL_CHANGE_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            mlflow-project|MLFLOW_PROJECT|MLFLOW_PROJECT_TEMPLATE|MLFLOW_PROJECT_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/mlops"
                safe_copy "$SCRIPT_DIR/common/templates/MLFLOW_PROJECT_TEMPLATE.md" "$TARGET_DIR/docs/mlops/MLFLOW_PROJECT_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            model-card|MODEL_CARD|MODEL_CARD_TEMPLATE|MODEL_CARD_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/mlops"
                safe_copy "$SCRIPT_DIR/common/templates/MODEL_CARD_TEMPLATE.md" "$TARGET_DIR/docs/mlops/MODEL_CARD_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            mlops-pipeline|MLOPS_PIPELINE|MLOPS_PIPELINE_CHECKLIST|MLOPS_PIPELINE_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/mlops"
                safe_copy "$SCRIPT_DIR/common/templates/MLOPS_PIPELINE_CHECKLIST.md" "$TARGET_DIR/docs/mlops/MLOPS_PIPELINE_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            agent-input-sanitization|AGENT_INPUT_SANITIZATION|AGENT_INPUT_SANITIZATION.md)
                ensure_dir "$TARGET_DIR/docs/agents"
                safe_copy "$SCRIPT_DIR/common/templates/AGENT_INPUT_SANITIZATION.md" "$TARGET_DIR/docs/agents/AGENT_INPUT_SANITIZATION.md"
                copied=$((copied + 1))
                ;;
            tool-sandboxing|TOOL_SANDBOXING|TOOL_SANDBOXING_CHECKLIST|TOOL_SANDBOXING_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/agents"
                safe_copy "$SCRIPT_DIR/common/templates/TOOL_SANDBOXING_CHECKLIST.md" "$TARGET_DIR/docs/agents/TOOL_SANDBOXING_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            agent-tool-design|AGENT_TOOL_DESIGN|AGENT_TOOL_DESIGN_CHECKLIST|AGENT_TOOL_DESIGN_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/agents"
                safe_copy "$SCRIPT_DIR/common/templates/AGENT_TOOL_DESIGN_CHECKLIST.md" "$TARGET_DIR/docs/agents/AGENT_TOOL_DESIGN_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            model-fallback|MODEL_FALLBACK|MODEL_FALLBACK_PLAYBOOK|MODEL_FALLBACK_PLAYBOOK.md)
                ensure_dir "$TARGET_DIR/docs/llmops"
                safe_copy "$SCRIPT_DIR/common/templates/MODEL_FALLBACK_PLAYBOOK.md" "$TARGET_DIR/docs/llmops/MODEL_FALLBACK_PLAYBOOK.md"
                copied=$((copied + 1))
                ;;
            tracking-plan|TRACKING_PLAN|TRACKING_PLAN_TEMPLATE|TRACKING_PLAN_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/analytics"
                safe_copy "$SCRIPT_DIR/common/templates/TRACKING_PLAN_TEMPLATE.md" "$TARGET_DIR/docs/analytics/TRACKING_PLAN.md"
                copied=$((copied + 1))
                ;;
            experiment|EXPERIMENT|EXPERIMENT_TEMPLATE|EXPERIMENT_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/analytics"
                safe_copy "$SCRIPT_DIR/common/templates/EXPERIMENT_TEMPLATE.md" "$TARGET_DIR/docs/analytics/EXPERIMENT_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            access-review|ACCESS_REVIEW|ACCESS_REVIEW_TEMPLATE|ACCESS_REVIEW_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/compliance"
                safe_copy "$SCRIPT_DIR/common/templates/ACCESS_REVIEW_TEMPLATE.md" "$TARGET_DIR/docs/compliance/ACCESS_REVIEW_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            audit-log|AUDIT_LOG|AUDIT_LOG_CHECKLIST|AUDIT_LOG_CHECKLIST.md)
                ensure_dir "$TARGET_DIR/docs/compliance"
                safe_copy "$SCRIPT_DIR/common/templates/AUDIT_LOG_CHECKLIST.md" "$TARGET_DIR/docs/compliance/AUDIT_LOG_CHECKLIST.md"
                copied=$((copied + 1))
                ;;
            vendor-risk|VENDOR_RISK|VENDOR_RISK_TEMPLATE|VENDOR_RISK_TEMPLATE.md)
                ensure_dir "$TARGET_DIR/docs/compliance"
                safe_copy "$SCRIPT_DIR/common/templates/VENDOR_RISK_TEMPLATE.md" "$TARGET_DIR/docs/compliance/VENDOR_RISK_TEMPLATE.md"
                copied=$((copied + 1))
                ;;
            *)
                warn "템플릿을 찾을 수 없음: ${item}"
                info "  사용 가능: pr, code-review, adr, design-doc, codeowners, agents, claude-md, gemini-md, gemini-settings, contributing, security-policy, license-review, prd, feature-spec, ai-task-spec, definition-of-done, project-memory, refactoring-plan, ai-review, handoff, codex-progress, subagent-spec, adversarial-review, ai-eval-harness, domain-model, layered-architecture, hexagonal-architecture, architecture-fitness, modular-monolith, cqrs-decision, event-contract, api-change, openapi, asyncapi, database-decision, database-selection, rdbms-schema-change, nosql-adoption, new-database, distributed-sql-readiness, data-retention, pii-classification, tenant-isolation, runbook, incident-postmortem, oncall-handoff, ai-cost-budget, cost-review, release-readiness, prompt-change, model-change, tracking-plan, experiment, access-review, audit-log, vendor-risk"
                ;;
        esac
    }

    if [[ -n "$pick" ]]; then
        IFS=',' read -ra items <<< "$pick"
        for item in "${items[@]}"; do
            item="$(echo "$item" | xargs)"
            copy_template_item "$item"
        done
    else
        copy_template_item "pr"
        info "PR 생성 시 자동으로 체크리스트가 표시됩니다"

        if [[ "$level" == "standard" || "$level" == "full" || "$level" == "enterprise" ]]; then
            copy_template_item "code-review"
            copy_template_item "adr"
            copy_template_item "agents"
            copy_template_item "claude-md"
            copy_template_item "gemini-md"
            copy_template_item "gemini-settings"
            copy_template_item "contributing"
            copy_template_item "security-policy"
            copy_template_item "license-review"
            copy_template_item "prd"
            copy_template_item "feature-spec"
            copy_template_item "ai-task-spec"
            copy_template_item "definition-of-done"
            copy_template_item "project-memory"
            copy_template_item "refactoring-plan"
            copy_template_item "ai-review"
            copy_template_item "handoff"
            copy_template_item "codex-progress"
            copy_template_item "subagent-spec"
            copy_template_item "adversarial-review"
            copy_template_item "ai-eval-harness"
            copy_template_item "database-decision"
            copy_template_item "database-selection"
            copy_template_item "rdbms-schema-change"
            copy_template_item "nosql-adoption"
            copy_template_item "data-retention"
            copy_template_item "pii-classification"
            copy_template_item "release-readiness"
            copy_template_item "prompt-change"
            copy_template_item "model-change"
            copy_template_item "tracking-plan"
            copy_template_item "experiment"
        fi

        if [[ "$level" == "full" || "$level" == "enterprise" ]]; then
            copy_template_item "design-doc"
            copy_template_item "codeowners"
            copy_template_item "domain-model"
            copy_template_item "layered-architecture"
            copy_template_item "hexagonal-architecture"
            copy_template_item "modular-monolith"
            copy_template_item "architecture-fitness"
            copy_template_item "cqrs-decision"
            copy_template_item "event-contract"
            copy_template_item "api-change"
            copy_template_item "openapi"
            copy_template_item "asyncapi"
            copy_template_item "new-database"
            copy_template_item "distributed-sql-readiness"
            copy_template_item "tenant-isolation"
            copy_template_item "runbook"
            copy_template_item "incident-postmortem"
            copy_template_item "oncall-handoff"
            copy_template_item "ai-cost-budget"
            copy_template_item "cost-review"
            copy_template_item "access-review"
            copy_template_item "audit-log"
            copy_template_item "vendor-risk"
            info "CODEOWNERS를 팀 구조에 맞게 수정하세요"
        fi
    fi

    success "템플릿 ${copied}개 적용 완료"
}

# ─── Component: Security Automation Templates ────────────────────────────
# 의존성 업데이트, 시크릿 탐지, 공급망 보안 자동화 템플릿.
apply_security_templates() {
    local level="${1:-standard}"
    local pick="${2:-}"

    header "보안 자동화 템플릿"

    local copied=0

    copy_security_item() {
        local item="$1"
        case "$item" in
            dependabot|dependabot.yml)
                ensure_dir "$TARGET_DIR/.github"
                safe_copy "$SCRIPT_DIR/common/security-templates/dependabot.yml" "$TARGET_DIR/.github/dependabot.yml"
                copied=$((copied + 1))
                ;;
            renovate|renovate.json)
                safe_copy "$SCRIPT_DIR/common/security-templates/renovate.json" "$TARGET_DIR/renovate.json"
                copied=$((copied + 1))
                ;;
            gitleaks|gitleaks.toml|.gitleaks.toml)
                safe_copy "$SCRIPT_DIR/common/security-templates/gitleaks.toml" "$TARGET_DIR/.gitleaks.toml"
                copied=$((copied + 1))
                ;;
            detect-secrets|detect-secrets.pre-commit|detect-secrets.pre-commit.yaml)
                safe_copy "$SCRIPT_DIR/common/security-templates/detect-secrets.pre-commit.yaml" "$TARGET_DIR/.pre-commit-config.detect-secrets.yaml"
                copied=$((copied + 1))
                ;;
            semgrep|.semgrep.yml)
                safe_copy "$SCRIPT_DIR/common/security-templates/.semgrep.yml" "$TARGET_DIR/.semgrep.yml"
                copied=$((copied + 1))
                ;;
            sonar|sonar-project.properties)
                safe_copy "$SCRIPT_DIR/common/security-templates/sonar-project.properties" "$TARGET_DIR/sonar-project.properties"
                copied=$((copied + 1))
                ;;
            sbom|sbom-ci|sbom-ci.yml)
                ensure_dir "$TARGET_DIR/.github/workflows"
                safe_copy "$SCRIPT_DIR/common/security-templates/sbom-ci.yml" "$TARGET_DIR/.github/workflows/sbom-ci.yml"
                copied=$((copied + 1))
                ;;
            *)
                warn "보안 템플릿을 찾을 수 없음: ${item}"
                info "  사용 가능: dependabot, renovate, gitleaks, detect-secrets, semgrep, sonar, sbom"
                ;;
        esac
    }

    if [[ -n "$pick" ]]; then
        IFS=',' read -ra items <<< "$pick"
        for item in "${items[@]}"; do
            item="$(echo "$item" | xargs)"
            copy_security_item "$item"
        done
    else
        copy_security_item "dependabot"
        copy_security_item "renovate"
        copy_security_item "gitleaks"
        copy_security_item "detect-secrets"

        if [[ "$level" == "full" || "$level" == "enterprise" ]]; then
            copy_security_item "semgrep"
            copy_security_item "sonar"
            copy_security_item "sbom"
        fi
    fi

    success "보안 템플릿 ${copied}개 적용 완료"
}

# ─── Component: GitHub Collaboration Infra ──────────────────────────────
# 이슈 폼 · 라벨 · 브랜치 ruleset · PR 정책 검사 · 보안 게이트 워크플로우.
# 브랜치 보호를 웹 UI 클릭이 아니라 git 의 JSON 으로 관리하고, 스크립트가 GitHub 에 반영한다.
apply_github_templates() {
    local level="${1:-standard}"
    local pick="${2:-}"

    header "GitHub 협업 인프라 (${level})"

    local src="$SCRIPT_DIR/common/github-templates"
    local github_dir="$TARGET_DIR/.github"
    local copied=0

    copy_github_scripts() {
        ensure_dir "$github_dir/scripts"
        safe_copy "$src/scripts/apply-github-settings.sh" "$github_dir/scripts/apply-github-settings.sh"
        [[ "$DRY_RUN" != true ]] && chmod +x "$github_dir/scripts/apply-github-settings.sh"
        return 0
    }

    copy_github_item() {
        local item="$1"
        case "$item" in
            issue-templates|issues|ISSUE_TEMPLATE)
                ensure_dir "$github_dir/ISSUE_TEMPLATE"
                for f in ai-task.yml bug-report.yml feature-request.yml config.yml; do
                    safe_copy "$src/ISSUE_TEMPLATE/$f" "$github_dir/ISSUE_TEMPLATE/$f"
                done
                copied=$((copied + 1))
                ;;
            labels|labels.json)
                ensure_dir "$github_dir"
                safe_copy "$src/labels.json" "$github_dir/labels.json"
                copy_github_scripts
                copied=$((copied + 1))
                ;;
            ruleset|rulesets|main-protection|ruleset-team)
                ensure_dir "$github_dir/rulesets"
                safe_copy "$src/rulesets/main-protection.json" "$github_dir/rulesets/main-protection.json"
                copy_github_scripts
                copied=$((copied + 1))
                ;;
            ruleset-solo|main-protection-solo)
                # 1인 저장소: 승인 1 + CODEOWNERS 를 만족할 다른 사람이 없어 팀용 ruleset 은 머지를 영원히 막는다
                ensure_dir "$github_dir/rulesets"
                safe_copy "$src/rulesets/main-protection-solo.json" "$github_dir/rulesets/main-protection.json"
                copy_github_scripts
                copied=$((copied + 1))
                ;;
            pr-checks|pr-policy|pr-checks.yml)
                ensure_dir "$github_dir/workflows" "$github_dir/scripts"
                safe_copy "$src/workflows/pr-checks.yml" "$github_dir/workflows/pr-checks.yml"
                safe_copy "$src/scripts/pr-policy.sh" "$github_dir/scripts/pr-policy.sh"
                [[ "$DRY_RUN" != true ]] && chmod +x "$github_dir/scripts/pr-policy.sh"
                copied=$((copied + 1))
                ;;
            security-review|security-review.yml)
                ensure_dir "$github_dir/workflows"
                safe_copy "$SCRIPT_DIR/common/security-templates/security-review.yml" "$github_dir/workflows/security-review.yml"
                copied=$((copied + 1))
                ;;
            ai-ready-guard|ai-ready-guard.yml)
                # "ai-ready 는 사람만 붙인다" 를 워크플로우로 강제 (봇·write 미만이 붙이면 라벨 제거 + 코멘트)
                ensure_dir "$github_dir/workflows" "$github_dir/scripts"
                safe_copy "$src/workflows/ai-ready-guard.yml" "$github_dir/workflows/ai-ready-guard.yml"
                safe_copy "$src/scripts/ai-ready-guard.sh" "$github_dir/scripts/ai-ready-guard.sh"
                [[ "$DRY_RUN" != true ]] && chmod +x "$github_dir/scripts/ai-ready-guard.sh"
                copied=$((copied + 1))
                ;;
            *)
                warn "GitHub 템플릿을 찾을 수 없음: ${item}"
                info "  사용 가능: issue-templates, labels, ruleset (팀용) | ruleset-solo (1인 저장소), pr-checks, security-review, ai-ready-guard"
                ;;
        esac
    }

    if [[ -n "$pick" ]]; then
        IFS=',' read -ra items <<< "$pick"
        for item in "${items[@]}"; do
            item="$(echo "$item" | xargs)"
            copy_github_item "$item"
        done
    else
        copy_github_item "issue-templates"
        copy_github_item "labels"
        # 팀용(승인 1 + CODEOWNERS)은 1인 저장소에서 본인 PR 을 승인할 사람이 없어 머지를 영원히 막는다 (--yes: solo)
        if confirm "  이 저장소는 1인용인가요? (예 → 승인자 없이 필수 체크만 거는 solo ruleset)" Y; then
            copy_github_item "ruleset-solo"
        else
            copy_github_item "ruleset"
        fi
        copy_github_item "pr-checks"
        copy_github_item "security-review"
        copy_github_item "ai-ready-guard"
    fi

    success "GitHub 템플릿 ${copied}개 적용 완료 → .github/"
    info "GitHub 에 반영: bash .github/scripts/apply-github-settings.sh  (라벨 + ruleset, 멱등)"
    info "언어 CI job (lint/test) 을 필수 체크로 넣으려면 .github/rulesets/main-protection.json 의 required_status_checks 에 추가"
    info "1인 저장소는 --pick ruleset-solo (승인 0 + admin PR bypass) — 팀용 ruleset 은 본인 PR 을 승인할 사람이 없어 머지가 막힌다"
}

# ─── Component: Language Templates ───────────────────────────────────────
# 언어별 린터/포매터/테스트 설정.
# 해당 언어의 bootstrap.sh를 실행하여 대화형으로 설정을 적용한다.
# 지원 언어: python, kotlin-spring, java-spring, typescript-react, go, rust, flutter-dart, swift, csharp-dotnet, ruby-rails
apply_lang() {
    if [[ "$TARGET_LANG" == "unknown" ]]; then
        warn "언어를 자동 감지할 수 없습니다."
        info "사용법: --lang python|kotlin-spring|java-spring|typescript-react|go|rust|flutter-dart|swift|csharp-dotnet|ruby-rails"
        return
    fi

    header "언어 템플릿: $TARGET_LANG"

    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] $TARGET_LANG/bootstrap.sh 실행 예정"
        return
    fi

    if [[ -d "$SCRIPT_DIR/$TARGET_LANG" ]]; then
        bash "$SCRIPT_DIR/$TARGET_LANG/bootstrap.sh" --target "$TARGET_DIR"
    else
        warn "언어 템플릿 디렉토리 없음: $TARGET_LANG"
    fi
}

# ─── Component: Guides ───────────────────────────────────────────────────
# 가이드 문서를 프로젝트 docs/guides/에 복사.
# --include-docs 플래그 또는 full/enterprise 레벨에서 자동 적용.
# --pick으로 특정 가이드만 선택 가능.
#
# 레벨별 포함 가이드:
#   standard:   코딩 스타일, Git 컨벤션, 시큐어 코딩, AI 협업 (5개)
#   full:       + REST API, 에러 핸들링, 성능, SLO, 배포, Design Doc,
#               인시던트, AI 코드 리뷰, 데이터 모델링, 분산 SQL (13개)
#   enterprise: docs/guides 전체
apply_guides() {
    local level="$1"
    local pick="$2"
    local dst="$TARGET_DIR/docs/guides"
    ensure_dir "$dst"

    header "가이드 문서"

    if [[ -n "$pick" ]]; then
        IFS=',' read -ra items <<< "$pick"
        for item in "${items[@]}"; do
            item="$(echo "$item" | xargs)"
            local src="$SCRIPT_DIR/docs/guides/${item}.md"
            [[ ! -f "$src" ]] && src="$SCRIPT_DIR/docs/guides/${item}-guide.md"
            if [[ -f "$src" ]]; then
                safe_copy "$src" "$dst/$(basename "$src")"
            else
                warn "가이드를 찾을 수 없음: ${item}"
                info "  사용 가능한 가이드:"
                find "$SCRIPT_DIR/docs/guides/" -name '*.md' | sed 's|.*/||' | sort | sed 's/-guide\.md//; s/\.md//' | while read -r g; do
                    echo "    - $g"
                done
            fi
        done
        return
    fi

    local guides=()
    case "$level" in
        slim)
            info "Slim 레벨: 가이드 문서 없음 (자동화가 품질을 강제합니다)"
            info "가이드가 필요하면: --include-docs 또는 --only guides --pick <이름>"
            return ;;
        standard)
            guides=(
                "coding-style-guide.md"
                "git-convention.md"
                "secure-coding-guide.md"
                "context-engineering-guide.md"
                "multi-agent-workflow-guide.md"
                "trunk-based-release-governance-guide.md"
                "llmops-promptops-guide.md"
                "product-analytics-experimentation-guide.md"
            ) ;;
        full)
            guides=(
                "coding-style-guide.md"
                "git-convention.md"
                "secure-coding-guide.md"
                "context-engineering-guide.md"
                "multi-agent-workflow-guide.md"
                "eval-driven-development-guide.md"
                "vibe-coding-to-production-guide.md"
                "rest-api-design-guide.md"
                "error-handling-guide.md"
                "performance-guide.md"
                "sli-slo-sla-guide.md"
                "deployment-strategy-guide.md"
                "design-doc-process.md"
                "incident-management-guide.md"
                "ai-code-review-guide.md"
                "data-modeling-guide.md"
                "distributed-sql-guide.md"
                "hexagonal-architecture-guide.md"
                "architecture-fitness-functions-guide.md"
                "modular-monolith-guide.md"
                "trunk-based-release-governance-guide.md"
                "llmops-promptops-guide.md"
                "product-analytics-experimentation-guide.md"
                "compliance-audit-readiness-guide.md"
            ) ;;
        enterprise)
            for f in "$SCRIPT_DIR/docs/guides/"*.md; do
                guides+=("$(basename "$f")")
            done ;;
    esac

    for guide in "${guides[@]}"; do
        if [[ -f "$SCRIPT_DIR/docs/guides/$guide" ]]; then
            safe_copy "$SCRIPT_DIR/docs/guides/$guide" "$dst/$guide"
        fi
    done

    success "가이드 ${#guides[@]}개 복사 완료 → docs/guides/"
}

# ─── Component: Meetings Scaffold ────────────────────────────────────────
# 회의록 관리 디렉토리를 스캐폴딩한다.
# meetings/ 디렉토리에 README, 용어집, 유형별 템플릿을 생성한다.
# AI 자동화 파이프라인 + 사람 보정 워크플로우를 위한 표준 구조.
apply_meetings() {
    local dst="$TARGET_DIR/meetings"

    header "회의록 스캐폴드"

    # README + glossary
    safe_copy "$SCRIPT_DIR/common/scaffold/meetings/README.md" "$dst/README.md"
    safe_copy "$SCRIPT_DIR/common/scaffold/meetings/glossary.md" "$dst/glossary.md"

    # Templates
    mkdir -p "$dst/templates"
    for tmpl in "$SCRIPT_DIR/common/scaffold/meetings/templates/"*.md; do
        [[ -f "$tmpl" ]] && safe_copy "$tmpl" "$dst/templates/$(basename "$tmpl")"
    done

    # Meetings rule
    local rules_dst="$TARGET_DIR/.claude/rules"
    mkdir -p "$rules_dst"
    safe_copy "$SCRIPT_DIR/common/rules/meetings.md" "$rules_dst/meetings.md"

    success "회의록 스캐폴드 적용 완료 → meetings/"
    info "glossary.md에 사내 용어와 인물 정보를 채워주세요"
}

# ─── Component: Gitignore ────────────────────────────────────────────────
# .gitignore에 공통 패턴을 추가한다.
# 기존 .gitignore가 없으면 새로 생성, 있으면 누락된 패턴만 추가.
apply_gitignore() {
    local gitignore="$TARGET_DIR/.gitignore"

    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] .gitignore 업데이트 예정"
        return
    fi

    local additions="$SCRIPT_DIR/common/gitignore-additions.txt"
    if [[ ! -f "$gitignore" ]]; then
        # 이 저장소 자신의 .gitignore 가 아니라 공용 패턴으로 만든다 (.env·node_modules·coverage 포함)
        cp "$additions" "$gitignore"
        success ".gitignore 생성 (공용 패턴)"
        return
    fi

    if [[ -f "$additions" ]]; then
        local added=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            # 줄 전체 일치로 비교한다 — 부분 문자열(-F)이면 ".env.local" 이 ".env" 를 가려 시크릿이 무시 목록에서 빠진다
            if ! grep -qxF -- "$line" "$gitignore" 2>/dev/null; then
                echo "$line" >> "$gitignore"
                added=$((added + 1))   # ((added++)) 는 값이 0 일 때 exit 1 → set -e 가 스크립트를 죽인다 (#13)
            fi
        done < "$additions"
        [[ $added -gt 0 ]] && success ".gitignore에 ${added}개 패턴 추가"
    fi

    # Claude Code 개인 설정은 항상 무시
    if ! grep -q "settings.local.json" "$gitignore" 2>/dev/null; then
        echo -e "\n# Claude Code (개인 설정)\n.claude/settings.local.json" >> "$gitignore"
    fi
}

# ─── Level Summary ───────────────────────────────────────────────────────
# 레벨별 적용 내용을 사전에 요약하여 보여준다.
show_level_summary() {
    local level="$1"

    echo -e "${BOLD}적용 예정 항목:${NC}"
    echo ""

    case "$level" in
        slim)
            echo -e "  ${GREEN}[Slim]${NC} 1~3명 소규모 팀 — 자동화만, 오버헤드 0"
            echo ""
            echo "  .claude/rules/         PRD/SPEC/TDD/Refactoring + Foundation + 언어별 규칙"
            echo "  .claude/hooks/         Hooks 5개 (auto-format + guard + test-receipt + receipt-lib + hooklib.py)"
            echo "  .claude/skills/        Skills 5개 (refactoring, vibe-to-production, ai-review-loop, ai-task-spec, plan-mode-workflow)"
            echo "  .claude/settings.json  팀 공유 설정"
            echo "  .gitignore             공통 무시 패턴"
            echo "  + 언어 린터/포매터     (선택)"
            ;;
        standard)
            echo -e "  ${YELLOW}[Standard]${NC} 4~10명 팀 — 자동화 + 핵심 가이드"
            echo ""
            echo "  Slim의 모든 것 +"
            echo "  .claude/rules/ +22     Architecture, Hexagonal, Modular Monolith, Fitness, DDD, Layered, API, Privacy,"
            echo "                         RDBMS/NoSQL/DB Governance, Trunk-Based Release, LLMOps, Product Analytics,"
            echo "                         Multi-Agent, AI Eval"
            echo "  .github/PR_TEMPLATE    PR 체크리스트"
            echo "  .github/ 협업 인프라   이슈 폼 3종, labels.json, rulesets/main-protection.json,"
            echo "                         workflows/pr-checks.yml + security-review.yml, scripts/"
            echo "  docs/adr/TEMPLATE      ADR 템플릿"
            echo "  docs/CODE_REVIEW       코드 리뷰 체크리스트"
            echo "  docs/product/specs     PRD, Feature Spec, AI Task Spec"
            echo "  docs/AI_* + DoD        완료 기준, Project Memory, Refactoring Plan, 리뷰 체크리스트"
            echo "  docs/database/privacy  DB Decision, DB Selection, RDBMS/NoSQL 체크리스트, 데이터 보존, PII 분류"
            echo "  docs/release/llmops    Release Readiness, Prompt/Model Change"
            echo "  docs/analytics         Tracking Plan, Experiment"
            echo "  보안 자동화             Dependabot, Renovate, Gitleaks, detect-secrets"
            [[ "$INCLUDE_DOCS" == true ]] && echo "  docs/guides/ x8        코딩, Git, 보안, Context, Multi-Agent, Trunk Release, LLMOps, Analytics"
            ;;
        full)
            echo -e "  ${BLUE}[Full]${NC} 11~30명 팀 — 아키텍처 + 운영"
            echo ""
            echo "  Standard의 모든 것 +"
            echo "  .claude/rules/ +9      Docker, GitHub Actions, OTel, EDD, Distributed SQL, Multi-Tenancy, Cost,"
            echo "                         CQRS/Event Sourcing, Compliance Audit"
            echo "  .github/CODEOWNERS     코드 소유권"
            echo "  docs/design/contracts  Design Doc, OpenAPI, AsyncAPI, API/Event Contract"
            echo "  docs/architecture      Hexagonal, Modular Monolith, Fitness, CQRS Decision Record"
            echo "  docs/runbooks/cost     Runbook, Postmortem, On-call, AI Cost Budget"
            echo "  docs/compliance        Access Review, Audit Log, Vendor Risk"
            echo "  보안 자동화             + Semgrep, Sonar, SBOM CI"
            echo "  docs/guides/ x24       API, 에러, 성능, SLO, 배포, 인시던트, 데이터, AI 협업, Hexagonal/Fitness/Modular,"
            echo "                         Trunk Release, LLMOps, Analytics, Compliance"
            ;;
        enterprise)
            echo -e "  ${RED}[Enterprise]${NC} 30명+ — 전체"
            echo ""
            echo "  Full의 모든 것 +"
            echo "  .claude/rules/ 전체    모든 Rules (k8s, terraform 등)"
            echo "  docs/guides/ 전체      48개 (MSA, Kafka, Saga, TiDB, AI 협업 등)"
            ;;
    esac

    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────
[[ -n "$MODE" ]] && run_check "$MODE"   # --check / --diff 는 아무것도 쓰지 않고 끝난다
echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     sos standards apply              ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  레벨  : ${GREEN}${LEVEL:-대화형 선택}${NC}"
echo -e "${CYAN}║${NC}  언어  : ${GREEN}${TARGET_LANG}${NC}"
echo -e "${CYAN}║${NC}  대상  : ${GREEN}${TARGET_DIR}${NC}"
[[ -n "$ONLY" ]] && echo -e "${CYAN}║${NC}  항목  : ${GREEN}${ONLY}${NC}"
[[ -n "$PICK" ]] && echo -e "${CYAN}║${NC}  선택  : ${GREEN}${PICK}${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${CYAN}║${NC}  모드  : ${YELLOW}DRY-RUN (미리보기)${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# --only mode: specific component only
if [[ -n "$ONLY" ]]; then
    case "$ONLY" in
        rules)     apply_rules "${LEVEL:-slim}" "$PICK" ;;
        hooks)     apply_hooks ;;
        skills)    apply_skills ;;
        settings)  apply_settings ;;
        templates) apply_templates "${LEVEL:-standard}" "$PICK" ;;
        security)  apply_security_templates "${LEVEL:-standard}" "$PICK" ;;
        github)    apply_github_templates "${LEVEL:-standard}" "$PICK" ;;
        guides)    apply_guides "${LEVEL:-standard}" "$PICK" ;;
        lang)      apply_lang ;;
        meetings)  apply_meetings ;;
        *)
            error "알 수 없는 컴포넌트: $ONLY"
            info "사용 가능: rules, hooks, skills, settings, templates, security, github, guides, lang, meetings"
            exit 1 ;;
    esac
    echo ""
    success "완료!"
    exit 0
fi

# --level mode: interactive selection if not specified
if [[ -z "$LEVEL" && "$ASSUME_YES" == true ]]; then
    error "--yes 는 대화형 레벨 선택을 할 수 없습니다 — --level slim|standard|full|enterprise 를 함께 주세요"
    exit 1
fi
if [[ -z "$LEVEL" ]]; then
    echo -e "${BOLD}팀 규모에 맞는 적용 레벨을 선택하세요:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${BOLD}slim${NC}       — 1~3명  자동화만, 오버헤드 0"
    echo -e "                    린터 + Hooks + PRD/SPEC/TDD/Refactoring Rules"
    echo ""
    echo -e "  ${YELLOW}2${NC}) ${BOLD}standard${NC}   — 4~10명 자동화 + PR 템플릿 + 핵심 가이드 5개"
    echo -e "                    + PRD/Feature Spec/AI Task/DoD/Refactoring/리뷰 루프"
    echo ""
    echo -e "  ${BLUE}3${NC}) ${BOLD}full${NC}       — 11~30명 아키텍처 + SRE + Design Doc"
    echo -e "                    + CODEOWNERS + API/Event Contract + Runbook + 가이드 13개"
    echo ""
    echo -e "  ${RED}4${NC}) ${BOLD}enterprise${NC} — 30명+  전체 (MSA, Kafka, Saga, TiDB, 온콜 등)"
    echo -e "                    모든 Rules + docs/guides 전체"
    echo ""
    echo -n "선택 (1-4): "
    read -r choice
    case "$choice" in
        1) LEVEL="slim" ;;
        2) LEVEL="standard" ;;
        3) LEVEL="full" ;;
        4) LEVEL="enterprise" ;;
        *) error "잘못된 선택 (1~4 중 선택)"; exit 1 ;;
    esac
    echo ""
fi

# Show summary before applying
show_level_summary "$LEVEL"

if [[ "$DRY_RUN" != true ]]; then
    if ! confirm "계속 진행하시겠습니까?" Y; then
        info "취소되었습니다."
        exit 0
    fi
fi

echo ""
info "레벨: $LEVEL 적용 시작"

# ─── Apply Components by Level ───────────────────────────────────────────
apply_gitignore
apply_rules "$LEVEL" ""
apply_hooks
apply_skills
apply_settings

if [[ "$LEVEL" != "slim" ]]; then
    apply_templates "$LEVEL" ""
    apply_security_templates "$LEVEL" ""
    apply_github_templates "$LEVEL" ""
fi

if [[ "$INCLUDE_DOCS" == true || "$LEVEL" == "full" || "$LEVEL" == "enterprise" ]]; then
    apply_guides "$LEVEL" ""
fi

# Language templates
if [[ "$TARGET_LANG" != "unknown" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        apply_lang
    else
        echo ""
        if confirm "$(echo -e "언어 템플릿(${BOLD}$TARGET_LANG${NC})도 적용하시겠습니까?")" Y; then
            apply_lang
        fi
    fi
fi

# ─── Completion Summary ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  적용 완료!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "적용된 항목:"
echo "  .claude/rules/           Claude Code 규칙"
echo "  .claude/hooks/           자동 포맷팅 + 위험 차단 + 테스트 영수증"
echo "  .claude/skills/          워크플로우 스킬 5개"
echo "  .claude/settings.json    팀 권한 설정"
[[ "$LEVEL" == "standard" ]] && echo "  .github/                  PR 템플릿, 이슈 폼, 라벨, ruleset, PR 체크·보안 게이트 워크플로우"
[[ "$LEVEL" == "full" || "$LEVEL" == "enterprise" ]] && echo "  .github/                  PR 템플릿, CODEOWNERS, 이슈 폼, 라벨, ruleset, PR 체크·보안 게이트 워크플로우"
[[ "$LEVEL" != "slim" ]] && echo "  docs/                     PRD, SPEC, AI 작업 명세, DoD, Refactoring, 리뷰 체크리스트"
[[ "$LEVEL" != "slim" ]] && echo "  보안 자동화               Dependabot, Renovate, Secret scan, Supply chain"
[[ "$INCLUDE_DOCS" == true || "$LEVEL" == "full" || "$LEVEL" == "enterprise" ]] && \
    echo "  docs/guides/              가이드 문서"
echo ""
echo -e "${BOLD}다음 단계:${NC}"
echo "  1. .claude/settings.json에서 팀에 맞게 권한 조정"
echo "  2. git add .claude/ .github/ docs/ && git commit -m '기능: sos 표준 적용'"
[[ "$LEVEL" != "slim" ]] && echo "  3. 라벨·브랜치 보호를 GitHub 에 반영: bash .github/scripts/apply-github-settings.sh"
echo "  4. 팀원에게 공유: git pull 후 Claude Code 실행"
echo ""
echo -e "${DIM}도움말: bash ${SCRIPT_DIR}/apply.sh --help${NC}"
echo -e "${DIM}업데이트: claude plugin marketplace update shiporsink && claude plugin update sos@shiporsink${NC}"
echo ""
