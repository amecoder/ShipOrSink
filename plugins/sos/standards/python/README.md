# Python / FastAPI 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 자동 적용

```bash
cd /path/to/my-python-project
bash "$SOS_STANDARDS/python/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. pyproject.toml에 Ruff + mypy + import-linter 추가

```bash
# 내용 확인 후 수동으로 pyproject.toml에 붙여넣기
cat "$SOS_STANDARDS/python/templates/pyproject-quality.toml"
```

수정 포인트:
- `target-version`: 프로젝트 Python 버전 (`py311`, `py312` 등)
- `src = ["src", "tests"]`: 소스 루트 디렉터리
- `per-file-ignores`: 파서/Repository 등 파일 특성에 맞게 조정
- `[tool.importlinter]`: `"app"` 네 곳(`root_package` · `containers` · `modules` · `source_modules`)을 프로젝트 최상위 패키지 이름으로. 쓰지 않는 계층은 `"(application)"` 처럼 괄호로 감싼다 — 그냥 두면 "Missing layer" 로 실패한다

### 2. .pre-commit-config.yaml 복사

```bash
cp "$SOS_STANDARDS/python/templates/.pre-commit-config.yaml" .

# ruff 버전 확인 후 rev 수정
ruff --version
# → .pre-commit-config.yaml의 rev: v0.14.14 를 로컬 버전으로 변경
```

> **주의**: ruff rev와 로컬 ruff 버전이 불일치하면
> `Unknown rule selector` 오류 발생. 반드시 일치시킬 것.

### 3. Claude Code 훅·설정 (공통)

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 4. detect-secrets baseline + pre-commit 설치

```bash
pip install pre-commit detect-secrets

detect-secrets scan \
  --exclude-files "tests/.*" \
  --exclude-files "\.venv/.*" \
  > .secrets.baseline

pre-commit install
pre-commit run --all-files  # 최초 전체 검사
```

---

## 포함된 템플릿

| 파일 | 설명 |
|------|------|
| `pyproject-quality.toml` | `[tool.ruff]` + `[tool.mypy]` + `[tool.importlinter]`(계층 계약 3개) 설정 (병합용) |
| `.pre-commit-config.yaml` | pre-commit 훅 5종 |

---

## 자주 나오는 위반 패턴과 수정법

### PERF401 — 루프 내 append → list comprehension

```python
# WRONG
result = []
for item in items:
    result.append(transform(item))

# RIGHT
result = [transform(item) for item in items]
existing.extend(x for x in items if condition(x))
```

### PLR1714 — 반복 비교 → in {}

```python
if x == "a" or x == "b"  →  if x in {"a", "b"}
if x != "-" and x != ""  →  if x not in {"-", ""}
```

### PLC0206 — dict 이터레이션

```python
for key in d: d[key]  →  for key, val in d.items()
```

### PLW2901 — 루프 변수 덮어쓰기

```python
# WRONG
for part in parts:
    part = part.strip()

# RIGHT
for part in (p.strip() for p in parts):
    ...
```

### SIM105/S110 — try/except/pass

```python
import contextlib

# WRONG
try:
    operation()
except Exception:
    pass

# RIGHT
with contextlib.suppress(Exception):
    operation()
```

### RUF003 — 모호한 유니코드 주석

```python
# WRONG: × (U+00D7), – (U+2013)
# was 3 × N   /  use max – typically same

# RIGHT
# was 3 x N   /  use max - typically same
```

### RUF043 — pytest.raises match raw string

```python
with pytest.raises(Err, match="[Ee]rror")   →   match=r"[Ee]rror"
```

### RUF012 — ClassVar 어노테이션

```python
from typing import ClassVar
class T:
    MAP: ClassVar[dict[str, str]] = {"a": "b"}
```

### function-length · file-size-limit — 50줄 넘는 함수 · 800줄 넘는 파일 (pre-commit 훅 + CI lint 잡)

ruff 에는 줄 수 규칙이 없어 `.pre-commit-config.yaml` 의 로컬 훅 두 개가 센다. 함수는 `def` 줄부터 마지막 줄까지(데코레이터 제외, 빈 줄·주석 포함), 파일은 물리 줄 수다. `src/` 만 본다.

```text
FAIL: src/app/service.py:12 build_report (64 lines, max 50)
FAIL: src/app/models.py (912 lines, max 800)
```

```python
# WRONG — 조회·계산·서식이 한 함수에
def build_report(rows): ...  # 64줄

# RIGHT — 단계마다 함수로 나누고, 본 함수는 순서만
def build_report(rows):
    totals = _sum_by_month(rows)
    return _render(totals)
```

파일이 크면 역할별 모듈로 나눈다(`models.py` → `models/order.py`, `models/invoice.py`).

### import-linter — 계층 경계 위반 (CI lint 잡 `Import contracts (import-linter)`)

`pyproject.toml` 의 `[tool.importlinter]` 계약 3개가 import 방향을 검사한다. 의존은 바깥(`adapter`)에서 안쪽(`domain`)으로만 향한다.

| 계약 | 막는 것 |
|---|---|
| `Onion layers: adapter -> application -> domain` | 안쪽 계층이 바깥 계층을 import (domain → application·adapter, application → adapter) |
| `Adapters do not import each other` | `adapter.web` ↔ `adapter.persistence` 처럼 어댑터끼리 (간접 경로 포함) |
| `Domain has no framework imports` | domain 이 fastapi·starlette·flask·django·sqlalchemy·sqlmodel 을 import (설치 여부와 무관) |

```text
Onion layers: adapter -> application -> domain BROKEN
...
Broken contracts
----------------

Onion layers: adapter -> application -> domain
----------------------------------------------

app.domain is not allowed to import app.adapter:

- app.domain.model -> app.adapter.web.routes (l.3)
```

```python
# WRONG — 도메인이 어댑터(ORM 저장소)를 직접 부른다
# src/app/domain/order.py
from app.adapter.persistence.repo import save

# RIGHT — 도메인·application 은 포트(Protocol)만 알고, 어댑터가 그것을 구현한다
# src/app/application/ports.py
class OrderRepository(Protocol):
    def save(self, order: Order) -> None: ...
# src/app/adapter/persistence/repo.py
class SqlOrderRepository:  # OrderRepository 를 구현 — 조립은 진입점(main.py)에서
    def save(self, order: Order) -> None: ...
```

로컬 실행: `PYTHONPATH=src uvx --from import-linter==2.15 lint-imports` (버전은 `ci-python.yml` 의 `IMPORT_LINTER_VERSION`).
예외가 꼭 필요하면 계약에 `ignore_imports = ["app.domain.x -> app.adapter.y"]` 를 달고, 바로 위 주석에 이유·날짜·담당자를 적는다(또는 ADR 로 남긴다 — `common/rules/architecture-fitness.md` 「Required Practice」).

주의할 점:
- 계층 폴더(`app/domain` · `app/application` · `app/adapter` · `app/adapter/<이름>`)마다 `__init__.py` 가 있어야 한다. 없으면 `Missing layer ... does not exist` 로 실패한다
- `adapter/` 바로 아래에는 어댑터 패키지만 둔다. `adapter/common.py` 처럼 공용 모듈을 두면 그것도 어댑터 하나로 보여, 다른 어댑터가 import 할 때 `Adapters do not import each other` 가 실패한다 — 공용 코드는 `application` 이나 별도 최상위 패키지로
- `SRC_DIR` 이 `src` 가 아니면(패키지가 저장소 루트에 있으면) 로컬 명령의 `PYTHONPATH=src` 도 같이 바꾼다(CI 는 `PYTHONPATH: ${{ env.SRC_DIR }}` 로 따라간다)
- 같은 계층 **안** 모듈끼리의 순환 import 는 검사하지 않는다(ArchUnit 템플릿의 `beFreeOfCycles` 와 다른 점)

---

## mypy strict 오류 패턴

```python
# 동적 dispatch → no-any-return
return await handler(args)  # type: ignore[no-any-return]

# Ellipsis sentinel → comparison-overlap
if val is not ...:  # type: ignore[comparison-overlap]

# dict.update(**kwargs) → arg-type
current.update(kwargs)  # type: ignore[arg-type]
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
| 실행 위치 | CI 템플릿 `common/ci-templates/ci-python.yml` 의 test 잡 — PR 에서만 도는 단계 `Coverage gate (changed lines + ratchet)`. 체크아웃은 `fetch-depth: 0`(비교할 base 브랜치가 있어야 한다), base 는 `origin/${{ github.base_ref }}` |
| 리포트 | `coverage.xml` — 테스트 단계의 `pytest --cov-report=xml:coverage.xml`(Cobertura) |
| 필요한 것 | runner 의 pipx(GitHub 호스트 러너에 기본 설치) 또는 uv |
| 로컬에서 직접 | `pytest --cov=src --cov-report=xml:coverage.xml && scripts/coverage-gate.sh coverage.xml` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage-langs.bats` 가 실제 pytest-cov 리포트로 CI 단계의 `run:` 을 그대로 실행한다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## Python 코딩 체크리스트

```
□ from __future__ import annotations  (모든 파일 첫 줄)
□ Protocol + @runtime_checkable  (ABC 대신)
□ NewType  (도메인 원시타입 래핑)
□ @dataclass(frozen=True) + tuple  (불변 모델)
□ Depends()  (FastAPI 인자 5개 이상)
□ 명명된 상수  (매직 넘버 금지)
□ contextlib.suppress  (try/except/pass 금지)
□ dict.items()  (dict[key] 반복 금지)
□ McCabe 복잡도 ≤ 15
□ 함수 50줄 · 파일 800줄 이하  (pre-commit function-length · file-size-limit)
□ import 방향 adapter → application → domain  (lint-imports — domain 에 프레임워크 import 없음)
□ public API Docstring  (Args/Returns/Raises)
```
