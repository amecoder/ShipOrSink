---
paths:
  - "**/prompts/**"
  - "**/chains/**"
  - "**/agents/**"
  - "**/embeddings/**"
  - "**/retrievers/**"
  - "**/notebooks/**"
  - "**/*.ipynb"
---

# AI/ML Rules

- `from __future__ import annotations` at top of every `.py` file
- Type hints on all public functions (mypy strict)
- Protocol over ABC for LLM/embedding/vector store interfaces
- `@dataclass(frozen=True)` + `tuple` for immutability (no mutable defaults)
- Pydantic models for all LLM structured outputs (no raw `json.loads()`)
- Named constants for model parameters: temperature, max_tokens, top_k, thresholds
- Google-style docstrings on all public APIs

## Prompt Management

- No hardcoded prompt strings (3+ lines) in Python code
- All prompts in versioned YAML files under `prompts/` directory
- Prompt templates use explicit `{variable}` substitution
- Temperature, max_tokens loaded from config (not hardcoded in code)
- System/user role separation in chat prompts

## LLM Client Patterns

- Centralized LLM client with retry + exponential backoff
- Fallback provider configured for production
- Token usage and cost tracked per invocation
- Timeout configured on all LLM API calls
- Rate limit handling with backpressure

## RAG Pipeline

- Chunking config as frozen dataclass (chunk_size, overlap, separators)
- Embedding model abstracted via Protocol (swappable)
- Vector store abstracted via Protocol (swappable)
- Batch embedding (no single-document loops)
- Score threshold on vector search results (filter irrelevant)
- Metadata filters for scoped retrieval

## Notebook Rules

- Notebooks are exploration-only (extract production logic to `.py`)
- Cell length: <= 20 lines
- Markdown cell before each code cell (explain intent)
- "Restart & Run All" must pass without errors
- No API keys or secrets in notebook cells (use `os.environ`)
- nbstripout: all outputs stripped before commit
- nbqa: ruff + mypy applied via pre-commit

## MLOps

- Experiment tracking (MLflow or W&B) for all model experiments
- Log: parameters, metrics, tags, artifacts
- Large data files via DVC (never commit to Git directly)
- Evaluation datasets versioned with semantic versioning
- Model deployment requires passing evaluation threshold

## Testing

- Deterministic tests: mock LLM, validate output schema (Pydantic)
- Non-deterministic tests: `@pytest.mark.evaluation`, separate pipeline
- RAG evaluation: Faithfulness >= 0.9, Recall@10 >= 0.85
- Prompt syntax tests in pre-commit (YAML parse + variable resolution)

## Forbidden

- Raw `json.loads()` on LLM output (use Pydantic validation)
- Hardcoded API keys or model endpoints
- `print()` in production code (use logging)
- Bare `except:` without specific exception
- Single-document embedding loops (use batch)
- Notebook outputs committed to Git
- `import *` (wildcard imports)
- Unversioned prompts in production
