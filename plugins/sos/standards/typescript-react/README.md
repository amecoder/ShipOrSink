# TypeScript / React / Next.js 품질 체계

## 포함 도구

| 도구 | 역할 | Python 대응 | Kotlin 대응 |
|------|------|-------------|-------------|
| **ESLint 9+** | 정적 분석, 복잡도, 코드 규칙 | ruff | detekt |
| **Prettier** | 코드 포매팅 | ruff format | ktlint |
| **TypeScript strict** | 타입 안전성 | mypy | Kotlin 컴파일러 |
| **Vitest** | 단위/통합 테스트 + 커버리지 (>= 80%) | pytest-cov | JaCoCo |
| **eslint-plugin-jsx-a11y** | 접근성 (WCAG 2.1 AA) | - | - |
| **eslint-plugin-react-hooks** | React 19 Hooks + Compiler 규칙 | - | - |
| **eslint-plugin-import-x** | import 순서/중복 관리 | ruff isort | ktlint |
| **Husky + lint-staged** | 커밋 전 자동 검사 | pre-commit | pre-commit |
| **dependency-cruiser** | 순환 import · 계층 방향(src/domain → 바깥 금지) | import-linter | ArchUnit |

## 자동 적용

```bash
cd /path/to/my-react-project
bash ~/.dev-standards/typescript-react/bootstrap.sh
```

## 수동 적용 (단계별)

### 1. ESLint Flat Config 복사

```bash
cp ~/.dev-standards/typescript-react/templates/eslint.config.mjs .
```

필요 패키지 설치 — 버전은 `templates/dev-dependencies.txt` 에 고정돼 있다(`bootstrap.sh` 가 그대로 설치한다). 버전 없이 받으면 eslint 10 과 `eslint-plugin-jsx-a11y`(eslint ≤9 지원)가 충돌해 `ERESOLVE` 로 실패한다:
```bash
grep -vE '^#|^$| (tailwind|if-missing)$' ~/.dev-standards/typescript-react/templates/dev-dependencies.txt | xargs npm install -D -E
# TypeScript 가 아직 없는 프로젝트만 — 이미 있으면 그 버전을 그대로 둔다 (bootstrap 과 같은 정책)
grep ' if-missing$' ~/.dev-standards/typescript-react/templates/dev-dependencies.txt | cut -d' ' -f1 | xargs npm install -D -E
```

`complexity` · `max-lines-per-function` · `max-lines` 는 `"error"` 다 — `"warn"` 이면 `eslint .` 가 exit 0 으로 끝나 CI 가 막지 않는다. 네 수치의 정본은 `common/quality-thresholds.yaml`, 실제로 막히는지는 `tests/enforcement.bats` 가 확인한다. 이 설정은 Next.js 프로젝트용이다(`eslint-config-next` 가 `next` 패키지의 파서를 불러온다). 테스트 파일(`*.test.*` · `*.spec.*` · `tests/` · `e2e/`)은 함수 길이 규칙에서 빠진다.

`vitest.config.ts` 의 `coverage.include` 는 모든 `.ts`/`.tsx` 를 대상으로 한다 — 없으면 테스트가 import 하지 않은 파일이 계산에서 빠져, 테스트가 없는 모듈이 있어도 80% 를 통과한다.

### 2. tsconfig.json에 품질 옵션 병합

```bash
cat ~/.dev-standards/typescript-react/templates/tsconfig-quality.json
```

기존 `tsconfig.json`의 `compilerOptions`에 아래 항목을 병합:
- `strict: true` — 엄격 타입 체크 전체 활성화
- `noUncheckedIndexedAccess: true` — 인덱스 접근 시 `undefined` 가능성 체크
- `noImplicitOverride: true` — 메서드 오버라이드 시 `override` 키워드 강제
- `exactOptionalPropertyTypes: true` — 옵셔널 프로퍼티에 `undefined` 명시적 할당 금지
- `forceConsistentCasingInFileNames: true` — 파일명 대소문자 일관성 강제

### 3. Prettier 설정 복사

```bash
cp ~/.dev-standards/typescript-react/templates/.prettierrc .
```

> **참고**: `prettier-plugin-tailwindcss`는 Tailwind CSS를 사용하는 프로젝트에서만 필요합니다.
> 미사용 시 `.prettierrc`의 `plugins` 배열에서 제거하세요.
>
> Tailwind CSS v4에서는 `tailwindStylesheet` 옵션으로 CSS 엔트리 포인트를 명시해야 합니다:
> ```json
> { "tailwindStylesheet": "./app/globals.css" }
> ```

### 4. Vitest 설정 복사

```bash
cp ~/.dev-standards/typescript-react/templates/vitest.config.ts .
```

필요 패키지 설치:
```bash
npm install -D vitest @vitejs/plugin-react @testing-library/react \
  @testing-library/jest-dom @testing-library/user-event jsdom
```

테스트 셋업 파일 생성:
```bash
mkdir -p tests
echo "import '@testing-library/jest-dom/vitest';" > tests/setup.ts
```

### 5. Husky + lint-staged 설정

```bash
npm install -D husky lint-staged
npx husky init
echo "npx lint-staged" > .husky/pre-commit
```

`package.json`에 lint-staged 설정 추가:
```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix --no-warn-ignored", "prettier --write"],
    "*.{json,md,yml,yaml}": ["prettier --write"],
    "*.{css,scss}": ["prettier --write"]
  }
}
```

### 6. Claude Code 훅 설정

```bash
bash ~/.dev-standards/apply.sh --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash ~/.dev-standards/apply.sh --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

> `permissions.allow` 목록을 프로젝트에 맞게 수정하세요.

### 7. dependency-cruiser 설정 복사

```bash
cp ~/.dev-standards/typescript-react/templates/.dependency-cruiser.cjs .
npx --no depcruise . --config .dependency-cruiser.cjs   # CI lint 잡 "Dependency rules" 와 같은 명령
```

프로젝트 전체(`.`)를 보고, 빌드 결과물(`.next`·`out`·`build`·`dist`·`coverage`)과 `node_modules` 내부는 건너뛴다. 계층 규칙은 `src/domain`·`src/application` 또는 루트의 `domain`·`application` 폴더에 걸린다. 경로 별칭(`@/…`)은 `tsconfig.json` 의 `paths` 로 풀고, 풀지 못한 import 는 `layers-no-unresolvable` 로 실패한다(별칭이 `tsconfig.app.json` 같은 다른 파일에만 있으면 설정의 `tsConfig.fileName` 을 바꾼다).

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `eslint.config.mjs` | ESLint 9+ Flat Config (TS + React Hooks + a11y + import 정렬) |
| `tsconfig-quality.json` | TypeScript strict 품질 옵션 (기존 tsconfig에 병합) |
| `.prettierrc` | Prettier 설정 + Tailwind 플러그인 |
| `vitest.config.ts` | Vitest + jsdom + v8 커버리지 (>= 80%) |
| `.husky-lint-staged` | Husky + lint-staged 설정 가이드 |
| `.dependency-cruiser.cjs` | 순환 import 금지 + src/domain·src/application 계층 방향 (dependency-cruiser 18) |

---

## 주요 npm 스크립트

`package.json`에 추가 권장(선택 — bootstrap 은 추가하지 않는다):

```json
{
  "scripts": {
    "prepare": "husky",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "lint:deps": "depcruise . --config .dependency-cruiser.cjs",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage"
  }
}
```

---

## 주요 위반 패턴 및 수정법

### 1. `@typescript-eslint/no-explicit-any` — any 타입 사용 금지

```typescript
// WRONG
function parse(data: any): string {
  return data.name;
}

// RIGHT: unknown + 타입 가드
function parse(data: unknown): string {
  if (typeof data === "object" && data !== null && "name" in data) {
    return (data as { name: string }).name;
  }
  throw new Error("Invalid data shape");
}

// RIGHT: 제네릭 사용
function parse<T extends { name: string }>(data: T): string {
  return data.name;
}
```

### 2. `react-hooks/exhaustive-deps` — useEffect 의존성 누락

```typescript
// WRONG: userId가 의존성 배열에 없음
useEffect(() => {
  fetchUser(userId);
}, []);

// RIGHT
useEffect(() => {
  fetchUser(userId);
}, [userId]);

// BETTER: useEffect 대신 이벤트 핸들러 또는 useMemo 사용
const user = useMemo(() => computeUser(userId), [userId]);
```

### 3. `jsx-a11y/alt-text` — 이미지 대체 텍스트 누락

```tsx
// WRONG
<img src="/photo.jpg" />
<Image src="/photo.jpg" width={200} height={200} />

// RIGHT
<img src="/photo.jpg" alt="사용자 프로필 사진" />
<Image src="/photo.jpg" width={200} height={200} alt="사용자 프로필 사진" />

// 장식용 이미지인 경우 빈 alt + role
<img src="/divider.svg" alt="" role="presentation" />
```

### 4. `no-console` — console.log 사용

```typescript
// WRONG
console.log("debug:", data);

// RIGHT: 디버깅 후 제거하거나 로거 사용
logger.debug("data fetched", { data });

// OK: warn, error는 허용됨
console.warn("Deprecated API usage");
console.error("Failed to fetch:", error);
```

### 5. `complexity` — 함수 복잡도 15 초과

```typescript
// WRONG: 중첩 분기가 과도한 함수
function processOrder(order: Order): Result {
  if (order.type === "standard") {
    if (order.items.length > 0) {
      if (order.payment === "card") {
        // ...15개 이상의 분기...
      }
    }
  }
}

// RIGHT: 전략 패턴 또는 함수 분리
function processOrder(order: Order): Result {
  const strategy = getProcessingStrategy(order.type);
  const validatedItems = validateItems(order.items);
  return strategy.execute(validatedItems, order.payment);
}
```

### 6. `import-x/order` — import 순서 불일치

```typescript
// WRONG: 정렬 안 된 import
import { Button } from "./Button";
import React from "react";
import type { FC } from "react";
import { useQuery } from "@tanstack/react-query";

// RIGHT: 그룹별 정렬 (자동 수정됨)
import React from "react";
import type { FC } from "react";

import { useQuery } from "@tanstack/react-query";

import { Button } from "./Button";
```

### 7. `@typescript-eslint/consistent-type-imports` — type import 분리

```typescript
// WRONG: 값과 타입 import 혼용
import { useState, type FC, type ReactNode } from "react";

// RIGHT: type-only import 분리 (auto-fixable)
import { useState } from "react";
import { type FC, type ReactNode } from "react";
```

### 8. dependency-cruiser — 순환 import · 계층 방향 위반 (CI lint 잡 `Dependency rules (dependency-cruiser)`)

| 규칙 | 막는 것 |
|---|---|
| `no-circular` | 모든 파일의 순환 import (a → b → a, 간접 경로 포함 · `import type` 만으로 생긴 순환도 포함) |
| `domain-no-outer-layers` | `domain` 이 프로젝트의 다른 폴더(components·app·application·types …)를 import |
| `domain-no-framework` | `domain` 이 react·react-dom·next 를 import (`import type` 포함, 설치 여부와 무관) |
| `application-no-outer-layers` | `application` 이 domain 말고 프로젝트의 다른 폴더를 import (npm 패키지는 막지 않는다) |
| `layers-no-unresolvable` | `domain`·`application` 의 import 를 풀지 못함 — 별칭 누락·오타가 위 규칙을 조용히 빠져나가지 않게 |

```text
  error domain-no-outer-layers: src/domain/bad.ts → src/components/Price.tsx

x 1 dependency violations (1 errors, 0 warnings). 6 modules, 5 dependencies cruised.
```

```typescript
// WRONG — 도메인 계산이 UI 컴포넌트를 불러온다
// src/domain/price.ts
import { formatPrice } from "@/components/PriceTag";

// RIGHT — 도메인은 값만 계산하고, 표시는 바깥(components)이 domain 을 불러서 한다
// src/domain/price.ts
export const totalPrice = (items: readonly Item[]): number => items.reduce((s, i) => s + i.price, 0);
// src/components/PriceTag.tsx
import { totalPrice } from "@/domain/price";
```

- `domain`·`application` 폴더가 없는 프로젝트는 `no-circular` 만 적용된다(계층 규칙은 해당 폴더가 생기면 바로 걸린다)
- domain 이 쓰는 공용 타입·유틸(`src/types`·`src/lib` 등)은 domain 안으로 옮긴다 — 바깥 폴더라서 `domain-no-outer-layers` 에 걸린다
- 모노레포는 앱 폴더에서 실행한다. workspace 패키지(`@acme/ui` 등)는 `node_modules` 가 아니라 실제 경로(`../../packages/ui/…`)로 풀려서, domain·application 이 import 하면 바깥 폴더로 보고 실패한다 — 공용 도메인 패키지를 써야 하면 그 경로를 규칙의 `pathNot` 예외로 단다
- 순환은 공통 부분을 세 번째 모듈로 빼서 끊는다. barrel(`index.ts`) 이 순환을 만드는 경우가 많다
- 예외가 꼭 필요하면 규칙의 `from`/`to` 에 `pathNot` 을 더하고, 바로 위 주석에 이유·날짜·담당자를 적는다(`common/rules/architecture-fitness.md` 「Required Practice」)

---

## TypeScript strict 주요 에러 패턴

### `noUncheckedIndexedAccess` — 인덱스 접근 타입

```typescript
const arr = [1, 2, 3];

// ERROR: Type 'number | undefined' is not assignable to type 'number'
const first: number = arr[0];

// RIGHT: undefined 가능성 처리
const first = arr[0];
if (first !== undefined) {
  doSomething(first); // first: number
}

// OR: non-null assertion (확실한 경우만)
const first = arr[0]!;
```

### `exactOptionalPropertyTypes` — 옵셔널 프로퍼티

```typescript
interface Config {
  timeout?: number;
}

// ERROR: Type 'undefined' is not assignable to type 'number'
const config: Config = { timeout: undefined };

// RIGHT: 프로퍼티 자체를 생략
const config: Config = {};

// OR: 타입에 undefined를 명시적으로 추가
interface Config {
  timeout?: number | undefined;
}
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
| 실행 위치 | CI 템플릿 `common/ci-templates/ci-typescript.yml` 의 test 잡 — PR 에서만 도는 단계 `Coverage gate (changed lines + ratchet)`. 체크아웃은 `fetch-depth: 0`(비교할 base 브랜치가 있어야 한다), base 는 `origin/${{ github.base_ref }}` |
| 리포트 | `coverage/lcov.info` — `vitest.config.ts` 의 reporter `lcov` |
| 필요한 것 | runner 의 pipx 또는 uv |
| 로컬에서 직접 | `npx vitest run --coverage && scripts/coverage-gate.sh coverage/lcov.info` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage-langs.bats` 가 vitest coverage-v8 모양(`SF:src/…`, 2026-11-10 실측)의 lcov 로 CI 단계를 실행한다 — vitest 자체는 그 테스트에서 돌리지 않는다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## TypeScript / React 코딩 체크리스트

```
타입 안전성
[ ] strict: true + noUncheckedIndexedAccess 활성화
[ ] any 타입 0개 (@typescript-eslint/no-explicit-any)
[ ] Props는 interface로 정의 (type보다 선호)
[ ] 제네릭 활용 (반복 타입 제거)
[ ] type import 분리 (consistent-type-imports)

컴포넌트 설계
[ ] Server Component 기본, 'use client'는 필요한 경우만
[ ] useEffect 최소화 (파생 상태는 useMemo, 이벤트는 핸들러)
[ ] 에러 바운더리 구현 (error.tsx)
[ ] 로딩 상태 구현 (loading.tsx 또는 Suspense)
[ ] next/image, next/link 사용
[ ] 순환 import 0 · src/domain 은 react·next·바깥 폴더 import 없음 (depcruise)

접근성
[ ] 모든 이미지에 alt 속성
[ ] 폼 요소에 label 연결
[ ] 키보드 네비게이션 가능
[ ] 적절한 ARIA 속성 사용
[ ] 색상 대비 WCAG AA 충족

품질
[ ] McCabe 복잡도 <= 15
[ ] 함수 <= 50줄
[ ] 파일 <= 800줄
[ ] no-console (warn/error 제외)
[ ] import 순서 정렬

테스트
[ ] Vitest + @testing-library/react
[ ] 커버리지 >= 80% (lines, branches, functions, statements)
[ ] E2E: Playwright (핵심 사용자 흐름)

보안
[ ] dangerouslySetInnerHTML 사용 시 DOMPurify 필수
[ ] 환경 변수: NEXT_PUBLIC_ 접두사 없이 서버 전용 변수 노출 금지
[ ] 하드코딩된 시크릿 없음
[ ] 사용자 입력 검증 (zod 권장)
```

---

## ESLint vs Biome 대안 안내

### 현재 기본: ESLint 9+ Flat Config + Prettier

이 템플릿의 기본 구성입니다. 프레임워크 플러그인 생태계가 가장 성숙하며, 모든 팀원이 익숙한 표준입니다.

| 장점 | 단점 |
|------|------|
| 플러그인 생태계 풍부 (300+ 코어 규칙) | 설정 복잡 (eslint + prettier + 플러그인) |
| jsx-a11y, react-hooks, import-x 등 성숙 | 대규모 프로젝트에서 속도 느림 |
| 커뮤니티 지원 최고 | 의존성 많음 (127+ npm 패키지) |

### 대안: Biome (React/Next.js 한정)

Biome v2.x는 React/JSX/TSX를 완전 지원합니다. 린터 + 포매터가 단일 바이너리에 통합되어 성능이 월등합니다.

| 장점 | 단점 |
|------|------|
| 56배 빠른 린팅 속도 | Next.js 전용 규칙 없음 |
| 단일 설정 (biome.json) | Tailwind 클래스 자동 정렬 미지원 |
| 내장 포매터 (Prettier 불필요) | 타입 인식 린팅 실험적 (2026 기준) |
| 423+ 내장 규칙 | jsx-a11y 규칙 일부만 포함 |

**Biome 권장 시나리오**:
- Tailwind CSS 미사용 프로젝트
- Next.js가 아닌 순수 React/Vite 프로젝트
- 대규모 모노레포에서 린팅 속도가 병목인 경우

**Biome 비권장 시나리오**:
- Tailwind CSS 사용 (클래스 정렬에 Prettier 필수)
- Next.js 프로젝트 (전용 린트 규칙 필요)
- WCAG 접근성 검사가 필수인 프로젝트

> Biome 설정 예시는 리서치 문서를 참고하세요:
> `docs/research/2026-03-11_프론트엔드-품질-도구-체계-리서치.md` (Section 4.1)

---

## 품질 기준 요약 (Python/Kotlin과 통일)

| 항목 | 기준값 | 도구 |
|------|--------|------|
| 커버리지 | >= 80% | vitest coverage v8 |
| 복잡도 | <= 15 | ESLint complexity |
| 함수 길이 | <= 50줄 | ESLint max-lines-per-function |
| 파일 크기 | <= 800줄 | ESLint max-lines |
| any 타입 | 0개 | @typescript-eslint/no-explicit-any |
| 보안 취약점 | 0 critical/high | npm audit |
