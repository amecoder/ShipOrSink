# Model Card — {Model Name} v{Version}

> 기반: Google Model Cards (Mitchell et al., 2019), Hugging Face Model Card Toolkit
> 작성 시점: YYYY-MM-DD
> 작성자: {Name / Team}

## 1. Model Details

| 항목 | 값 |
|------|----|
| 모델명 | |
| 버전 | |
| 학습 일자 | |
| 모델 유형 | (분류 / 회귀 / 생성 / RAG / fine-tuned LLM 등) |
| 아키텍처 | (예: BERT-base, ResNet-50, XGBoost) |
| 라이선스 | (예: MIT, Apache 2.0, 사내 전용) |
| 학습 프레임워크 | (예: PyTorch 2.5, scikit-learn 1.5) |
| 학습 비용 (USD) | |
| 학습 시간 / 자원 | (예: 8x A100, 12시간) |
| MLflow Run URL | |
| Git Commit SHA | |
| 데이터 버전 | (DVC commit hash 또는 데이터셋 버전) |
| 환경 hash | (Docker image digest 등) |

## 2. Intended Use

### Primary Use Cases
- (이 모델이 답하려는 문제)
- (예상 사용자 / 서비스)

### Out-of-Scope Use Cases
- (사용 금지: 의료 진단, 법률 자문, 채용 결정 등)
- (이유)

### Potential Misuse
- (악용 시나리오 + 방어책)

## 3. Training Data

| 항목 | 값 |
|------|----|
| 데이터셋명 | |
| 출처 | |
| 수집 기간 | |
| 샘플 수 (train / val / test) | |
| 라벨링 프로세스 | (인간 / 자동 / hybrid) |
| 데이터 라이선스 | |
| PII 포함 여부 | (Yes / No / 마스킹) |
| 보호 속성(protected attributes) | (성별 / 인종 / 연령 등) |
| 클래스 불균형 | |
| 알려진 한계 | |

### Data Card 링크: {URL}

## 4. Evaluation

### Quantitative Metrics

| 메트릭 | Validation | Test | Production (실측) | 임계값 | Pass/Fail |
|--------|-----------|------|-------------------|--------|-----------|
| Accuracy | | | | >= 0.85 | |
| Precision | | | | >= 0.80 | |
| Recall | | | | >= 0.80 | |
| F1 | | | | >= 0.82 | |
| AUC-ROC | | | | >= 0.90 | |
| Latency p50/p95 (ms) | | | | <= 100/500 | |

### Slice Performance (저빈도 / 보호 그룹)

| 슬라이스 | N | Accuracy | F1 | 비고 |
|----------|---|----------|----|----|
| 전체 | | | | |
| 그룹 A | | | | |
| 그룹 B | | | | |
| 엣지 케이스 1 | | | | |

### Fairness

| 보호 속성 | 메트릭 | 격차 | 임계값 | Pass/Fail |
|-----------|--------|------|--------|-----------|
| 성별 | Demographic parity | | <= 0.05 | |
| 연령대 | Equalized odds | | <= 0.05 | |
| 지역 | Predictive parity | | <= 0.05 | |

### Adversarial / Robustness
- (적대적 입력 / Out-of-distribution / Drift 시나리오 평가 결과)

## 5. Comparison With Baseline / Prior Version

| 메트릭 | Baseline / v(N-1) | 현재 | Delta |
|--------|-------------------|------|-------|
| Accuracy | | | |
| F1 | | | |
| Latency p95 | | | |
| Cost / 1k inferences (USD) | | | |
| 모델 크기 (MB) | | | |

회귀 항목 / 트레이드오프 설명: ...

## 6. Limitations

- 학습 데이터 분포 이외에서 성능 저하 가능
- (특정 입력 길이 / 도메인 / 언어에서 약함)
- (알려진 실패 모드)

## 7. Ethical Considerations

- 보호 그룹에 대한 영향 평가
- 거짓 양성 / 거짓 음성의 비대칭 비용
- 사용자 프라이버시 보호 조치
- 결정 권한이 인간에게 있는지 (HITL)

## 8. Operational Information

| 항목 | 값 |
|------|----|
| 배포 환경 | (예: Kubernetes, SageMaker Endpoint, Triton) |
| 입력 스키마 | (Pydantic / Proto / JSON Schema URL) |
| 출력 스키마 | |
| 재학습 주기 | (예: 매주 / 데이터 drift 임계값 초과 시) |
| 모니터링 대시보드 | (URL) |
| On-call runbook | (URL) |
| 롤백 절차 | (이전 버전 URL + 검증 단계) |
| 비용 모니터링 알람 임계값 | |

## 9. Approval

- [ ] ML Engineer (학습 / 평가)
- [ ] Product / Domain Expert (Intended Use 검토)
- [ ] Privacy / Legal (PII / 라이선스)
- [ ] Security (Threat model / Adversarial)
- [ ] SRE / DevOps (배포 / 모니터링)
- [ ] On-call (Runbook 검토)

## 10. References

- Training run: {MLflow URL}
- Code commit: {GitHub URL}
- Dataset card: {URL}
- Architecture diagram: {URL}
- Original paper / blog: {URL if applicable}
