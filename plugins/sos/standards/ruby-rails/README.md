# Ruby / Rails 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Python 대응 | Go 대응 |
|------|------|-------------|---------|
| **RuboCop** + 확장팩 | 메타 린터 (스타일 + 품질) | ruff + mypy | golangci-lint |
| **rubocop-rails** | Rails 특화 규칙 | — | — |
| **rubocop-performance** | 성능 안티 패턴 | — | gocritic |
| **rubocop-rspec** | RSpec 모범 사례 | pytest 규칙 | testifylint |
| **rubocop-thread_safety** | 스레드 안전성 검사 | — | — |
| **Brakeman** | Rails 정적 보안 분석 (SAST) | bandit | gosec |
| **bundler-audit** | 알려진 CVE 의존성 스캔 | pip-audit | govulncheck |
| **SimpleCov** | 커버리지 (>= 80%) | pytest-cov | go test -cover |
| **erb_lint** | ERB 템플릿 검사 | — | — |
| **detect-secrets** | 시크릿 스캔 | 동일 | 동일 |
| **pre-commit** | 커밋 전 자동 검사 | 동일 | 동일 |

## 자동 적용

```bash
cd /path/to/my-rails-project
bash "$SOS_STANDARDS/ruby-rails/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. Gemfile에 품질/보안 gem 추가

```ruby
group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false   # .rubocop.yml inherit_gem
  gem "rubocop-rails", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-thread_safety", require: false
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rspec-rails"             # Rails인 경우
  gem "simplecov", require: false
  gem "erb_lint", require: false
end
```

```bash
bundle install
```

### 2. .rubocop.yml 복사

```bash
cp "$SOS_STANDARDS/ruby-rails/templates/.rubocop.yml" .
```

수정 포인트:
- `AllCops.TargetRubyVersion`: 프로젝트 Ruby 버전 (예: 3.3, 3.4)
- `AllCops.TargetRailsVersion`: 프로젝트 Rails 버전
- `Metrics.MethodLength.Max`: 함수 길이 (기본 50)
- `Metrics.CyclomaticComplexity.Max`: 순환 복잡도 (기본 15)

> **Metrics 규칙마다 `Enabled: true` 가 있어야 한다.** `.rubocop.yml` 이 상속하는 `rubocop-rails-omakase` 는 부서 단위로
> Metrics·Style·Naming·Lint·Layout·Rails·Performance 등을 `Enabled: false` 로 끄고, 자기가 고른 일부 규칙만 개별로 다시 켠다 —
> `Max:` 같은 옵션만 적힌 규칙은 꺼진 채다. 2026-11-06 전 템플릿은 Metrics 에 `Enabled` 가 없어 83줄·분기 21개 메서드도
> "no offenses" 였다(`tests/enforcement-ruby.bats` 로 확인). 지금은 Metrics 8개(MethodLength · AbcSize 30 · ClassLength 300 ·
> ModuleLength 300 · CyclomaticComplexity · PerceivedComplexity · ParameterLists 5 · BlockLength 50)가 모두 켜진다 —
> 앞의 둘 외에는 정본(복잡도·함수·파일·커버리지) 밖의 추가 한도다.
> **옵션만 적혀 있어 지금도 꺼져 있는 규칙 9개**(2026-11-06 해석 결과 기준): `Layout/LineLength`(120) · `Layout/MultilineMethodCallIndentation` ·
> `Style/StringLiteralsInInterpolation` · `Style/ClassAndModuleChildren` · `Style/RaiseArgs` · `Naming/PredicatePrefix` ·
> `Naming/MethodParameterName` · `Lint/MissingSuper` · `Lint/EmptyClass` — 쓰려면 각각 `Enabled: true` 를 단다
>
> - 세는 방법: 복잡도 `1 + 분기 수`(`if` 로 확인). `PerceivedComplexity` 15 가 함께 막는데, 이 규칙은 `if/else` 를 2로 세서 더 엄격하다 —
>   `if/else` 8개(순환 복잡도 9)짜리 메서드도 17/15 로 막힌다.
>   메서드 길이는 `def`~`end` 사이 코드 줄(빈 줄·주석 제외), 파일 800 은 pre-commit `file-size-limit` 훅(실제 줄 수)
> - 최소 버전: **RuboCop 1.76 · rubocop-thread_safety 0.7** — `plugins:` 문법(1.72+, `require:` 는 폐기 예정 경고)과 바뀐 규칙 이름
>   (`ThreadSafety/InstanceVariableInClassMethod` → `ClassInstanceVariable`, `Naming/PredicateName` → `PredicatePrefix`) 때문이다.
>   더 낮은 버전으로 잠긴 프로젝트에 이 `.rubocop.yml` 을 덮어쓰면 모르는 키·규칙 오류가 날 수 있다
> - rubocop 훅은 `bundle exec rubocop --autocorrect --fail-fast --force-exclusion` 이다. 예전 원격 훅(`repo: https://github.com/rubocop/rubocop`)을
>   쓰는 프로젝트는 `.pre-commit-config.yaml` 을 다시 복사한다 — 그 훅은 omakase 젬이 없어 시작하지 못했다
> - 커버리지 80% 는 `spec_helper.rb` 맨 위의 `require "simplecov"` + `SimpleCov.start` 가 `.simplecov` 를 불러와야 걸린다(pre-push `rspec` 훅,
>   `spec/` 이 있는 RSpec 프로젝트만 — Minitest 만 쓰는 `test/` 프로젝트는 훅이 건너뛴다).
>   SimpleCov 1.3 은 `.simplecov` 안의 `SimpleCov.start`·`add_filter`·`add_group` 과 `minimum_coverage_by_file` 을 폐기 예정으로 경고한다(아직 동작)

### 3. .editorconfig 복사

```bash
cp "$SOS_STANDARDS/ruby-rails/templates/.editorconfig" .
```

### 4. .simplecov 복사 + spec_helper.rb 수정

```bash
cp "$SOS_STANDARDS/ruby-rails/templates/.simplecov" .
```

`spec/spec_helper.rb` 또는 `test/test_helper.rb` 최상단에 다음 추가:

```ruby
require "simplecov"
SimpleCov.start
```

### 5. .pre-commit-config.yaml 복사

```bash
cp "$SOS_STANDARDS/ruby-rails/templates/.pre-commit-config.yaml" .
```

### 6. Claude Code 훅·설정 (공통)

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 7. detect-secrets baseline + pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan --exclude-files "(vendor|tmp|log|storage|node_modules)/.*" > .secrets.baseline
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `.rubocop.yml` | RuboCop + 확장팩 5개 (rails, performance, rspec, rake, thread_safety) |
| `.editorconfig` | 에디터 공통 설정 |
| `.simplecov` | SimpleCov 설정 (커버리지 80%, 분기 커버리지 활성) |
| `.pre-commit-config.yaml` | commit: `bundle exec rubocop --autocorrect` / push: brakeman + rspec(SimpleCov 80%) + bundler-audit |

---

## 주요 명령어

```bash
# 린트 + 자동 수정
bundle exec rubocop --autocorrect
bundle exec rubocop --autocorrect-all  # 안전하지 않은 자동 수정 포함

# 린트 (CI용 — 변경 없이 검증만)
bundle exec rubocop

# Rails 보안 스캔
bundle exec brakeman --quiet --no-pager

# 알려진 CVE 의존성 스캔
bundle exec bundler-audit check --update

# 테스트 + 커버리지
bundle exec rspec
COVERAGE=true bundle exec rspec   # SimpleCov 활성

# ERB 템플릿 린트
bundle exec erb_lint --lint-all

# 의존성 업데이트 가능 항목
bundle outdated
```

---

## RuboCop 부서 (Departments)

| 부서 | 설명 | 예시 |
|------|------|------|
| **Layout** | 들여쓰기, 정렬, 공백 | `Layout/LineLength` (120자) |
| **Lint** | 잠재 버그 (의심스러운 구문) | `Lint/UnusedMethodArgument` |
| **Metrics** | 복잡도 / 길이 측정 | `Metrics/CyclomaticComplexity` (15) |
| **Naming** | 명명 규칙 | `Naming/PredicateName` (is_/has_ 금지) |
| **Style** | 코딩 스타일 | `Style/StringLiterals` (double_quotes) |
| **Bundler** | Gemfile 검사 | `Bundler/OrderedGems` |
| **Rails** | Rails 특화 | `Rails/HasManyOrHasOneDependent` |
| **Performance** | 성능 안티 패턴 | `Performance/StringReplacement` |
| **RSpec** | RSpec 모범 사례 | `RSpec/ExampleLength` (20줄) |
| **ThreadSafety** | 스레드 안전성 | `ThreadSafety/ClassAndModuleAttributes` |

---

## 자주 나오는 위반 패턴과 수정법

### 1. Rails/HasManyOrHasOneDependent — dependent 옵션 명시

```ruby
# WRONG: dependent 누락
class User < ApplicationRecord
  has_many :posts
end

# RIGHT: dependent 명시 (destroy / delete_all / nullify / restrict_with_*)
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
end
```

### 2. Rails/SkipsModelValidations — 검증 우회 메서드

```ruby
# WRONG: 검증을 우회하는 메서드 사용
user.update_column(:email, new_email)
User.update_all(active: false)

# RIGHT: 검증을 거치는 메서드
user.update!(email: new_email)
User.find_each { |u| u.update!(active: false) }
```

### 3. Rails/InverseOf — has_many/belongs_to에 inverse_of

```ruby
# WRONG: inverse_of 누락
class Post < ApplicationRecord
  belongs_to :user
end

class User < ApplicationRecord
  has_many :posts
end

# RIGHT: inverse_of 명시 (또는 conventional 이름이면 자동 추론)
class Post < ApplicationRecord
  belongs_to :user, inverse_of: :posts
end

class User < ApplicationRecord
  has_many :posts, inverse_of: :user
end
```

### 4. Rails/UniqueValidationWithoutIndex — uniqueness + DB 인덱스

```ruby
# WRONG: 모델만 uniqueness 검증 (race condition 발생)
class User < ApplicationRecord
  validates :email, uniqueness: true
end

# RIGHT: DB에 unique 인덱스 추가 (마이그레이션)
class AddUniqueIndexToUsersEmail < ActiveRecord::Migration[7.2]
  def change
    add_index :users, :email, unique: true
  end
end
```

### 5. Style/HashSyntax — Ruby 3.1+ shorthand

```ruby
# WRONG: 변수와 키 이름이 같을 때 명시적
{ name: name, email: email, age: age }

# RIGHT: shorthand 문법 (Ruby 3.1+)
{ name:, email:, age: }
```

### 6. Performance/StringReplacement — gsub vs tr

```ruby
# WRONG: 단일 문자 치환에 gsub 사용
str.gsub("a", "b")

# RIGHT: tr이 5배 이상 빠름
str.tr("a", "b")
```

### 7. ThreadSafety/MutableClassInstanceVariable — 가변 클래스 인스턴스 변수

```ruby
# WRONG: 가변 객체를 클래스 인스턴스 변수로
class Config
  @cache = {}  # 스레드 간 공유 (race condition)

  def self.cache; @cache; end
end

# RIGHT: 동기화된 자료구조 또는 thread-local
require "concurrent"

class Config
  @cache = Concurrent::Map.new

  def self.cache; @cache; end
end
```

### 8. Lint/UselessAssignment — 사용되지 않는 변수

```ruby
# WRONG: 할당 후 사용 안 함
def calculate(x)
  result = x * 2  # 사용되지 않음
  x + 1
end

# RIGHT: _ 접두사로 의도 표현 또는 제거
def calculate(x)
  x + 1
end
```

### 9. Brakeman — SQL 인젝션

```ruby
# WRONG: 문자열 보간으로 SQL 생성
User.where("email = '#{params[:email]}'")

# RIGHT: 파라미터 바인딩
User.where(email: params[:email])
User.where("email = ?", params[:email])
```

### 10. Rails/Output — puts/pp 대신 Rails.logger

```ruby
# WRONG: 프로덕션 코드에 puts/p
def process(order)
  puts "Processing #{order.id}"
end

# RIGHT: Rails.logger 사용
def process(order)
  Rails.logger.info "Processing order #{order.id}"
end
```

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음 (전체 80% 검사와 함께)

전체 커버리지 80% 검사는 그대로 두고, 그 위에 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 하나 더 건다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: base 브랜치 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

두 검사를 함께 두는 이유(2026-11-10 결정): 전체 80% 는 바닥을 지키고, 바뀐 줄 검사는 전체 검사가 놓치는 것을 잡는다.
예를 들어 전체가 90% 인 프로젝트에 테스트 없는 새 코드 50줄을 넣어도 전체는 80% 를 넘어 통과하지만, 바뀐 줄 검사는 그 50줄이 0% 라서 막는다.
대신 전체가 80% 아래인 기존 프로젝트는 무엇을 바꾸든 먼저 전체를 80% 까지 올려야 push·PR 이 통과한다.

| 항목 | 내용 |
|---|---|
| 실행 위치 | pre-push 훅 `coverage-gate` — 리포트를 쓰는 훅 `rspec` 바로 뒤에서 돈다(같은 파일 조건) |
| 리포트 | `coverage/coverage.xml` — `.simplecov` 의 `SimpleCov::Formatter::CoberturaFormatter`(젬 `simplecov-cobertura`, bootstrap 의 Gemfile 안내에 있다). SimpleCov 1.3 에는 lcov·Cobertura 출력기가 없다 |
| 필요한 것 | 젬 `simplecov-cobertura` · uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 로컬에서 직접 | `bundle exec rspec && scripts/coverage-gate.sh coverage/coverage.xml` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-ruby.bats` 가 실제 rspec + SimpleCov + simplecov-cobertura 가 쓴 리포트로 `coverage-gate` 훅을 실행한다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## Ruby/Rails 코딩 체크리스트

```
스타일
[] frozen_string_literal: true 모든 .rb 파일
[] double_quotes 통일 (StringLiterals)
[] hash shorthand (Ruby 3.1+: { name:, email: })
[] trailing comma (배열/해시 멀티라인)

Rails
[] dependent 옵션 명시 (has_many/has_one)
[] inverse_of 명시
[] uniqueness 검증은 DB unique index와 짝
[] update_column / update_all 검증 우회 금지
[] Rails.logger > puts/pp

품질
[] 메서드 길이 <= 50줄 (Metrics/MethodLength)
[] 순환 복잡도 <= 15 (Metrics/CyclomaticComplexity)
[] 클래스 길이 <= 300줄
[] 파일 <= 800줄
[] 파라미터 <= 5개

보안
[] Brakeman 경고 0건
[] bundle audit: 0 vulnerabilities
[] SQL 파라미터 바인딩 (인젝션 방지)
[] strong_parameters 사용 (mass assignment)
[] 하드코딩된 시크릿 없음 (detect-secrets)

성능
[] tr > gsub (단일 문자 치환)
[] N+1 쿼리: bullet gem 또는 includes / preload
[] DB 인덱스: foreign_key, 자주 조회되는 컬럼

테스트
[] RSpec 또는 Minitest 사용
[] 커버리지 >= 80% (SimpleCov)
[] 분기 커버리지(branch coverage) 활성
[] FactoryBot으로 fixture 대체
[] system specs로 E2E (capybara)

스레드 안전성
[] @class_var는 Concurrent::Map 또는 thread-local
[] ActiveRecord 컨넥션 풀 충분 확보
[] Sidekiq Worker는 idempotent
```
