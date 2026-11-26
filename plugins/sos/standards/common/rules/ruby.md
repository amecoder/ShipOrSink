---
paths:
  - "**/*.rb"
  - "Gemfile"
  - "Rakefile"
---

# Ruby 코딩 규칙

## 기본 설정

- 모든 Ruby 파일 첫 줄에 `# frozen_string_literal: true` 매직 코멘트를 추가한다
- 이는 문자열 리터럴을 기본적으로 불변(frozen)으로 만들어 성능을 개선하고 의도치 않은 변경을 방지한다

```ruby
# frozen_string_literal: true

class UserService
  # ...
end
```

## RuboCop 준수

- 프로젝트 루트에 `.rubocop.yml`을 반드시 배치한다
- `rubocop-rails`, `rubocop-rspec`, `rubocop-performance` 확장을 기본 포함한다
- CI에서 `rubocop --fail-level warning` 으로 경고도 차단한다

```yaml
# .rubocop.yml
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3
  Exclude:
    - 'db/schema.rb'
    - 'bin/**/*'
    - 'vendor/**/*'

Metrics/MethodLength:
  Max: 50

Metrics/ClassLength:
  Max: 600

Metrics/CyclomaticComplexity:
  Max: 15

Metrics/PerceivedComplexity:
  Max: 15
```

## Rails 패턴: Fat Model, Thin Controller

- Controller는 요청 파싱, 인가, 응답 반환만 담당한다 (10줄 이내 권장)
- 비즈니스 로직은 Model 또는 Service Object에 위치시킨다
- 복잡한 쿼리는 Scope 또는 Query Object로 추출한다

```ruby
# frozen_string_literal: true

# BAD: business logic in controller
class OrdersController < ApplicationController
  def create
    order = Order.new(order_params)
    order.total = order.items.sum(&:price) * (1 - discount_rate)
    order.status = :pending
    order.save!
    OrderMailer.confirmation(order).deliver_later
    # ... 30 lines more
  end
end

# GOOD: thin controller + service object
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.call(order_params, current_user:)

    if result.success?
      render json: result.order, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
end
```

## Service Object 패턴

- `app/services/` 디렉토리에 배치한다
- `.call` 클래스 메서드를 단일 진입점으로 사용한다
- 결과 객체(Result/Response)를 반환하여 성공/실패를 명시한다

```ruby
# frozen_string_literal: true

module Orders
  class CreateService
    def self.call(params, current_user:)
      new(params, current_user:).call
    end

    def initialize(params, current_user:)
      @params = params
      @current_user = current_user
    end

    def call
      order = build_order
      return failure(order.errors) unless order.valid?

      order.save!
      notify(order)
      success(order)
    end

    private

    attr_reader :params, :current_user

    def build_order
      Order.new(params.merge(user: current_user, status: :pending))
    end

    def notify(order)
      OrderMailer.confirmation(order).deliver_later
    end

    def success(order) = OpenStruct.new(success?: true, order:, errors: [])
    def failure(errors) = OpenStruct.new(success?: false, order: nil, errors:)
  end
end
```

## Brakeman 보안

- Brakeman은 Rails 전용 정적 보안 분석 도구이다
- CI에서 `brakeman --no-pager -q` 실행을 필수화한다
- High confidence 이슈는 즉시 수정, Medium은 스프린트 내 해결

```bash
# CI command
brakeman --no-pager --quiet --confidence-level 2 --exit-on-warn
```

### Brakeman 주요 검출 항목

| 카테고리 | 예시 |
|----------|------|
| SQL Injection | `User.where("name = '#{params[:name]}'")` |
| XSS | `raw(user_input)`, `html_safe` 남용 |
| Mass Assignment | `permit` 없이 `params` 직접 전달 |
| CSRF | `protect_from_forgery` 누락 |
| Redirect | `redirect_to params[:url]` (open redirect) |
| File Access | `File.read(params[:path])` (path traversal) |

## 불변성 패턴

- 비즈니스 로직에서 `.freeze`를 적극 사용한다
- 상수는 반드시 `.freeze`한다
- `Struct`에 `keyword_init: true`를 사용하면 가독성이 높아진다

```ruby
# frozen_string_literal: true

ALLOWED_STATUSES = %w[pending active completed cancelled].freeze

# Value object with Struct
OrderSummary = Struct.new(:id, :total, :status, keyword_init: true) do
  def active? = status == "active"
end
```

## 테스트

- RSpec을 기본 테스트 프레임워크로 사용한다
- `let` / `let!`으로 테스트 데이터를 선언적으로 정의한다
- Factory Bot으로 테스트 데이터를 생성한다
- `simplecov`로 커버리지를 측정하고 80% 이상을 유지한다

## 품질 기준

| 메트릭 | 기준 |
|--------|------|
| 메서드 길이 | 50줄 이하 |
| 클래스 길이 | 600줄 이하 |
| 순환 복잡도 | 15 이하 |
| 테스트 커버리지 | 80% 이상 |
| Brakeman 경고 | 0건 (High/Medium) |

## 도구

| 역할 | 도구 |
|------|------|
| 린터/포매터 | RuboCop |
| 보안 | Brakeman, bundler-audit |
| 테스트 | RSpec + Factory Bot |
| 커버리지 | SimpleCov |
| 의존성 보안 | bundle audit, Snyk |
