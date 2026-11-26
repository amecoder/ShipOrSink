---
paths:
  - "**/*.py"
  - "pyproject.toml"
  - "requirements*.txt"
---

# Python Rules

- `from __future__ import annotations` at top (Python <=3.12)
- Type hints on all public functions (mypy strict)
- Protocol over ABC (structural subtyping)
- `@dataclass(frozen=True)` + `tuple` for immutability (no mutable defaults)
- `contextlib.suppress()` over empty try/except/pass
- Named constants over magic numbers
- `NewType` for domain primitives (`UserId`, `Email`)
- Google-style docstrings on all public APIs
- 6+ params in FastAPI → `Depends()` pattern
- Line length: 99 chars (project standard)
- McCabe complexity: <=15
- Function length: <=50 lines
- File size: <=800 lines

## Forbidden

- `any` type annotations
- Mutable default arguments (`def f(items=[]): ...`)
- Bare `except:` without specific exception
- `print()` in production code (use logging)
- Hardcoded secrets
- `import *` (wildcard imports)
