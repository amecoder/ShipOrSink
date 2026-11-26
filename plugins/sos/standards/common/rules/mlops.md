---
paths:
  - "**/mlruns/**"
  - "**/mlflow/**"
  - "**/MLproject"
  - "**/conda.yaml"
  - "**/dvc.yaml"
  - "**/.dvc/**"
  - "**/feature_store/**"
  - "**/feast/**"
  - "**/pipelines/**"
  - "**/training/**"
  - "**/serving/**"
---

# MLOps Pipeline Rules

전통적인 코드와 다르게 ML 시스템은 **코드 + 데이터 + 모델** 3축으로 변경된다. 모든 변경은 재현 가능해야 하고, 모든 운영 모델은 추적 가능해야 한다.

## Pipeline Stages (필수 단계)

1. **Data Ingestion** — 원본 데이터 수집, 버전 고정 (DVC / LakeFS / Delta Lake)
2. **Data Validation** — Schema 검증 (Great Expectations / Pandera), drift 검사
3. **Data Preparation** — Feature engineering, 학습/검증/테스트 분할
4. **Training** — 실험 추적 (MLflow / W&B), 하이퍼파라미터 로깅
5. **Evaluation** — 오프라인 메트릭 + 페어니스 + 슬라이스 평가
6. **Model Validation** — 게이트 통과 (이전 모델 대비 회귀 없음)
7. **Deployment** — Canary / Shadow / A/B로 단계적 배포
8. **Monitoring** — 입력 drift, 출력 drift, performance decay, 비용

## Reproducibility (필수)

- `MLproject` (MLflow Project) 또는 동등한 entrypoint 정의
- 환경: `conda.yaml` / `requirements.txt` / `Dockerfile` 중 1개 이상으로 고정
- Random seed 명시 (numpy, torch, tf 모두)
- Git commit SHA + 데이터 버전 + 환경 hash가 실험 메타데이터에 포함
- "한 명령으로 재실험"이 가능해야 함 (예: `mlflow run . -P alpha=0.5`)

## Experiment Tracking (필수)

모든 학습은 다음을 추적 시스템(MLflow / W&B / Neptune)에 기록한다:

- **Parameters**: 하이퍼파라미터, 데이터 버전, feature flag
- **Metrics**: 학습/검증 loss + 비즈니스 메트릭 (per-epoch + final)
- **Artifacts**: 모델 weights, confusion matrix, feature importance, sample predictions
- **Tags**: git commit SHA, branch, environment (dev/staging/prod), 데이터 버전
- **Source**: 학습 스크립트 경로 + 명령어

## Data Versioning (필수)

- 학습 데이터는 Git에 직접 커밋 금지 (대용량 → DVC / LakeFS / S3 버전 관리)
- 학습/검증/테스트 분할 결과를 버전 고정
- 데이터 변경 시 데이터 카드(Data Card) 갱신
- PII/민감 데이터는 마스킹된 샘플만 저장

## Model Registry

- 학습 후 통과한 모델만 Registry 등록 (예: MLflow Model Registry)
- Stage 라이프사이클: `None` → `Staging` → `Production` → `Archived`
- Production 등록 전 다음을 통과해야 함:
  - 오프라인 평가 게이트 (회귀 < 임계값)
  - Fairness 게이트 (보호 속성별 성능 차이 < 임계값)
  - 테스트 슬라이스 게이트 (저빈도 클래스 / 엣지 케이스)
  - 안전성 검사 (PII 노출 / 적대적 입력 / 라이선스)
- 모델 카드(Model Card) 필수 첨부

## Deployment Patterns

| 패턴 | 용도 | 트래픽 | 롤백 시간 |
|------|------|--------|-----------|
| **Shadow** | 새 모델을 백그라운드로 평행 실행, 결과는 미반영 | 100% (백그라운드) | 즉시 |
| **Canary** | 소수 트래픽에 새 모델 적용 | 1~10% | 분 단위 |
| **Blue/Green** | 100% 전환, 이전 버전 대기 | 0% → 100% | 분 단위 |
| **A/B** | 통계적 비교 | 50/50 | 실험 종료 |
| **Multi-armed Bandit** | 동적 할당으로 최적 모델 학습 | 적응적 | 자동 |

기본은 **Shadow → Canary → 100%**. Bandit은 정량 KPI가 명확한 경우만.

## Online Monitoring (필수)

다음을 SLI로 정의하고 알람 임계값을 설정:

- **Input drift**: feature 분포 변화 (PSI / KL / KS test)
- **Output drift**: 예측 분포 변화
- **Performance decay**: 정답이 늦게 들어오는 지연 평가 메트릭
- **Latency**: p50 / p95 / p99
- **Throughput**: requests/sec
- **Error rate**: 모델 호출 실패율
- **Resource**: GPU/CPU/메모리 활용률
- **Cost**: per-request 비용 + 일별 총합

## Feature Store (선택)

여러 모델이 같은 feature를 공유하는 경우:

- 학습 시점과 추론 시점의 feature 일관성 보장 (training-serving skew 방지)
- Feature 정의는 코드로 (Feast `FeatureView` 등)
- Online store (Redis/DynamoDB) + Offline store (S3/BigQuery) 분리
- Point-in-time correctness (시간 누수 방지)

## Forbidden

- 학습 코드에 하드코딩된 데이터 경로 (실험 추적 시스템에서 데이터 버전 로드)
- "마지막 학습 결과" 가 어디 저장됐는지 모름 (반드시 추적 시스템에)
- 모델 weights를 Git에 직접 커밋 (>50MB 권장 외)
- Registry에 등록되지 않은 모델로 프로덕션 추론
- `random.seed()` 누락
- 검증 데이터로 학습 (data leakage)
- 모델 카드 없이 프로덕션 배포
- Drift / decay 모니터링 없이 배포 후 방치
- Training-serving feature 정의 분리 (이중 구현)

## Approval Gate (배포 전 필수)

- [ ] 실험 추적 시스템에 학습 결과 등록 완료 (URL)
- [ ] `MODEL_CARD_TEMPLATE.md` 작성 완료
- [ ] 오프라인 평가 게이트 통과 (회귀 ≤ 임계값)
- [ ] Fairness 게이트 통과 (보호 속성별 격차 ≤ 임계값)
- [ ] Production Shadow / Canary 단계 통과
- [ ] Drift / decay 모니터링 대시보드 연결 (URL)
- [ ] 롤백 절차 검증 완료 (이전 버전 latency 검증)
- [ ] On-call runbook 갱신
