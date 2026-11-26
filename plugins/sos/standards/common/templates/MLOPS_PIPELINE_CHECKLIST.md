# MLOps Pipeline Checklist

ML 시스템을 프로덕션에 배포하기 전 통과해야 하는 8단계 게이트.

## 1. Reproducibility 게이트

- [ ] `MLproject` (또는 동등한 entrypoint) 정의되어 있음
- [ ] 환경 고정: `conda.yaml` / `requirements.txt` / `Dockerfile` 중 1개 이상
- [ ] Random seed 명시 (numpy, torch, tf, sklearn 모두)
- [ ] "한 명령으로 재실험" 검증 완료 (`mlflow run . -P seed=42` 결과 동일)
- [ ] Git commit SHA + 데이터 버전 + 환경 hash가 실험 메타데이터에 포함

## 2. Data Quality 게이트

- [ ] 데이터 스키마 정의 + 검증 (Pandera / Great Expectations)
- [ ] 학습/검증/테스트 분할 stratified + seed 고정
- [ ] Data leakage 검증 (시간 기반 분할, target leakage)
- [ ] Class imbalance 평가 + 처리 (oversampling / weighted loss)
- [ ] PII 마스킹 / 익명화 완료
- [ ] 데이터 라이선스 + 출처 문서화 (Data Card)
- [ ] 데이터 버전 고정 (DVC / LakeFS / S3 versioning)

## 3. Experiment Tracking 게이트

- [ ] MLflow / W&B / Neptune 중 하나에 모든 학습 기록
- [ ] Logged: parameters / metrics (per-epoch + final) / artifacts / tags
- [ ] Tag: `git_commit`, `data_version`, `environment`, `branch`
- [ ] Confusion matrix / ROC / feature importance 등 artifact 저장
- [ ] Run에서 모델 + 입력 예시 + signature 등록

## 4. Evaluation 게이트

- [ ] 오프라인 메트릭 임계값 통과 (예: F1 ≥ 0.82)
- [ ] Slice 평가 (보호 그룹별, 저빈도 클래스, 엣지 케이스)
- [ ] Fairness 게이트 (보호 속성별 성능 격차 ≤ 임계값)
- [ ] Adversarial / OOD 입력 평가
- [ ] 이전 버전 / Baseline 대비 회귀 분석
- [ ] 비즈니스 메트릭 시뮬레이션 (예측 → 의사결정 → 결과)

## 5. Model Registry 게이트

- [ ] Model Registry에 등록 (MLflow Model Registry / SageMaker Model Registry)
- [ ] `MODEL_CARD_TEMPLATE.md` 작성 + 첨부
- [ ] Stage 라이프사이클: None → Staging → Production
- [ ] Production 전환 전 codify된 게이트 통과 (코드로 검증, 수동 X)
- [ ] 이전 Production 버전을 Archived로 이동

## 6. Deployment 게이트

- [ ] 배포 패턴 명시 (Shadow → Canary → 100% 권장)
- [ ] 입력/출력 스키마 정의 (Pydantic / Proto / OpenAPI)
- [ ] Health check + readiness probe 구현
- [ ] 롤백 절차 검증 (이전 버전 latency / accuracy 측정)
- [ ] 부하 테스트 통과 (목표 RPS, p95 latency)
- [ ] Blue/Green 또는 Rolling 배포 구성

## 7. Monitoring 게이트

- [ ] **Input drift**: PSI / KL / KS test 알람 설정
- [ ] **Output drift**: 예측 분포 변화 알람
- [ ] **Performance decay**: 지연 평가 메트릭 (라벨이 늦게 도착)
- [ ] **Latency**: p50 / p95 / p99 SLO 정의
- [ ] **Throughput**: requests/sec
- [ ] **Error rate**: 모델 호출 실패율
- [ ] **Resource**: GPU/CPU/메모리 활용률
- [ ] **Cost**: per-request + 일별 총합 알람
- [ ] Drift / decay 트리거 시 자동 재학습 또는 인간 알림

## 8. Operational 게이트

- [ ] On-call runbook 갱신 (장애 시 대응 절차)
- [ ] 모니터링 대시보드 URL 등록
- [ ] 사고 대응 시뮬레이션 (예: 모델이 모든 입력에 동일 출력)
- [ ] PII / 보안 검토 통과 (보호 데이터가 모델 출력에 누출되지 않음)
- [ ] Compliance 검토 (GDPR / EU AI Act 해당 시)
- [ ] 비용 예산 + 알람 설정
- [ ] Stakeholder 승인 (Product / Privacy / SRE / Security)

---

## Anti-patterns (즉시 차단)

- [BLOCK] 학습 코드에 하드코딩된 데이터 경로
- [BLOCK] "마지막 학습 결과"가 어디 있는지 모름
- [BLOCK] Registry에 등록되지 않은 모델로 프로덕션 추론
- [BLOCK] 검증 데이터로 학습 (data leakage)
- [BLOCK] 모델 카드 없이 프로덕션 배포
- [BLOCK] Drift / decay 모니터링 없이 배포 후 방치
- [BLOCK] Training-serving feature 정의 분리 (이중 구현)
- [BLOCK] Random seed 누락
- [BLOCK] 모델 weights를 Git에 직접 커밋 (>50MB)

---

## 관련 템플릿

- [`MLFLOW_PROJECT_TEMPLATE.md`](MLFLOW_PROJECT_TEMPLATE.md) — 재현 가능 학습 구조
- [`MODEL_CARD_TEMPLATE.md`](MODEL_CARD_TEMPLATE.md) — 모델 카드
- [`MODEL_CHANGE_TEMPLATE.md`](MODEL_CHANGE_TEMPLATE.md) — 모델 / 프롬프트 변경 이력
- [`AI_EVAL_HARNESS_TEMPLATE.md`](AI_EVAL_HARNESS_TEMPLATE.md) — 평가 회귀
- [`AI_COST_BUDGET_TEMPLATE.md`](AI_COST_BUDGET_TEMPLATE.md) — 비용 예산
