# README 템플릿

> 프로젝트 README.md의 표준 구조. 이 템플릿을 복사하여 프로젝트에 맞게 수정한다.

---

## 템플릿

```markdown
# 프로젝트명

프로젝트에 대한 간결한 설명 (1-2문장).

## 주요 기능

- 기능 1: 간략한 설명
- 기능 2: 간략한 설명
- 기능 3: 간략한 설명

## 기술 스택

| 영역 | 기술 |
|------|------|
| 언어 | Python 3.12 / Kotlin 2.x / TypeScript 5.x |
| 프레임워크 | FastAPI / Spring Boot / Next.js |
| 데이터베이스 | PostgreSQL |
| 인프라 | Docker, GitHub Actions |

## 사전 요구사항

- [언어 런타임] >= [버전]
- [패키지 매니저] >= [버전]
- [기타 도구]

## 빠른 시작

### 설치

\```bash
# 레포지토리 클론
git clone https://github.com/org/project.git
cd project

# 의존성 설치
pip install -e ".[dev]"  # Python
# 또는
./gradlew build          # Kotlin/Spring Boot
# 또는
npm install              # TypeScript/Node
\```

### 환경 설정

\```bash
# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 필요한 값 입력
\```

### 실행

\```bash
# 개발 서버 실행
uvicorn app.main:app --reload     # Python
# 또는
./gradlew bootRun                  # Kotlin/Spring Boot
# 또는
npm run dev                        # TypeScript/Node
\```

## 프로젝트 구조

\```
src/
├── domain/          # 도메인 모델, 비즈니스 규칙
├── application/     # 유스케이스, 서비스
├── infrastructure/  # DB, 외부 API, 설정
└── presentation/    # API 핸들러, DTO
\```

## 개발

### 코드 품질

\```bash
# 린트
ruff check .                      # Python
./gradlew detekt                  # Kotlin
npm run lint                      # TypeScript

# 포맷
ruff format .                     # Python
./gradlew ktlintFormat            # Kotlin
npm run format                    # TypeScript

# 타입 체크
mypy src/                         # Python
npm run typecheck                 # TypeScript
\```

### 테스트

\```bash
# 단위 테스트
pytest                            # Python
./gradlew test                    # Kotlin
npm test                          # TypeScript

# 커버리지
pytest --cov=src --cov-report=html
./gradlew jacocoTestReport
npm run test:coverage
\```

## API 문서

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 배포

### 환경별 설정

| 환경 | URL | 브랜치 |
|------|-----|--------|
| Development | http://dev.example.com | `main` (자동) |
| Staging | http://staging.example.com | 태그 `v*-rc*` |
| Production | http://example.com | 태그 `v*` |

## 기여 가이드

1. Feature 브랜치 생성: `git checkout -b feat/기능명`
2. 변경 사항 구현 + 테스트 작성
3. PR 생성 ([PR 템플릿](.github/PULL_REQUEST_TEMPLATE.md) 참고)
4. 코드 리뷰 후 Squash Merge

자세한 개발 규칙은 아래 문서를 참고:
- [코딩 스타일 가이드](docs/guides/coding-style-guide.md)
- [Git 컨벤션](docs/guides/git-convention.md)
- [코드 리뷰 체크리스트](common/templates/CODE_REVIEW_CHECKLIST.md)

## 라이선스

[MIT](LICENSE) / [Apache 2.0](LICENSE)
```
