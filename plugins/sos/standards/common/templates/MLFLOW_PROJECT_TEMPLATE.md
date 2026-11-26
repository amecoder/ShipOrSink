# MLflow Project Template

재현 가능한 ML 실험을 위한 MLflow Project 표준 템플릿. `MLproject` + `conda.yaml` + 학습 스크립트로 "한 명령으로 재실험"을 보장한다.

## 1. 디렉토리 구조

```
my-ml-project/
├── MLproject                    # Entry point + parameters
├── conda.yaml                   # 환경 (선택1)
├── requirements.txt             # 환경 (선택2)
├── Dockerfile                   # 환경 (선택3, 권장)
├── src/
│   ├── train.py                 # 학습 스크립트
│   ├── evaluate.py              # 평가 스크립트
│   ├── deploy.py                # 모델 배포
│   └── data/
│       ├── load.py
│       └── validate.py          # Great Expectations 등
├── tests/
│   ├── test_train.py
│   ├── test_data.py
│   └── test_model.py
├── configs/
│   ├── train.yaml               # 학습 하이퍼파라미터
│   └── eval.yaml                # 평가 임계값
├── data/                        # DVC로 버전 관리 (Git에는 .dvc 파일만)
│   └── .gitignore
├── dvc.yaml                     # DVC 파이프라인
├── notebooks/                   # 탐색 전용 (nbstripout 적용)
└── README.md
```

## 2. MLproject 파일 (entry point)

```yaml
name: my-ml-project

# 환경 — conda / docker / virtualenv 중 하나
docker_env:
  image: my-ml-project:latest

# conda_env: conda.yaml
# python_env: python_env.yaml

entry_points:
  main:
    parameters:
      data_version: {type: str, default: "v1.0.0"}
      learning_rate: {type: float, default: 0.001}
      batch_size: {type: int, default: 32}
      epochs: {type: int, default: 10}
      seed: {type: int, default: 42}
    command: >
      python src/train.py
      --data-version {data_version}
      --lr {learning_rate}
      --batch-size {batch_size}
      --epochs {epochs}
      --seed {seed}

  evaluate:
    parameters:
      run_id: str
      eval_data: {type: str, default: "data/test.csv"}
    command: "python src/evaluate.py --run-id {run_id} --eval-data {eval_data}"

  deploy:
    parameters:
      model_version: int
      stage: {type: str, default: "Staging"}
    command: "python src/deploy.py --model-version {model_version} --stage {stage}"
```

## 3. 학습 스크립트 표준 (src/train.py)

```python
from __future__ import annotations

import argparse
import os
import random

import mlflow
import mlflow.sklearn
import numpy as np


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    # torch / tf seed는 사용 시 추가


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-version", required=True)
    parser.add_argument("--lr", type=float, default=0.001)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    set_seed(args.seed)

    # MLflow tracking
    mlflow.set_experiment("my-experiment")
    with mlflow.start_run() as run:
        # 1. Parameters
        mlflow.log_params(vars(args))
        mlflow.set_tag("git_commit", os.environ.get("GIT_COMMIT", "local"))
        mlflow.set_tag("environment", os.environ.get("ENV", "dev"))
        mlflow.set_tag("data_version", args.data_version)

        # 2. Load + train (구현 필요)
        # X_train, y_train = load_data(args.data_version)
        # model = train(X_train, y_train, lr=args.lr, ...)

        # 3. Metrics (per-epoch + final)
        # for epoch in range(args.epochs):
        #     mlflow.log_metric("train_loss", train_loss, step=epoch)
        #     mlflow.log_metric("val_loss", val_loss, step=epoch)

        # 4. Artifacts
        # mlflow.log_artifact("confusion_matrix.png")
        # mlflow.log_artifact("feature_importance.csv")

        # 5. Model — Registry에 자동 등록
        # mlflow.sklearn.log_model(
        #     sk_model=model,
        #     artifact_path="model",
        #     registered_model_name="my-model",
        #     signature=mlflow.models.infer_signature(X_train, model.predict(X_train)),
        #     input_example=X_train.iloc[:5],
        # )

        print(f"Run ID: {run.info.run_id}")


if __name__ == "__main__":
    main()
```

## 4. conda.yaml (환경 고정)

```yaml
name: my-ml-project
channels:
  - conda-forge
dependencies:
  - python=3.11
  - pip
  - pip:
      - mlflow==2.18.0
      - scikit-learn==1.5.2
      - pandas==2.2.3
      - numpy==2.1.3
      - pytest==8.3.3
```

## 5. 한 명령으로 재실험

```bash
# Local
mlflow run . -P data_version=v1.0.0 -P learning_rate=0.001

# Git repo (URI)
mlflow run https://github.com/org/my-ml-project.git \
  -P data_version=v1.0.0 \
  -P learning_rate=0.001

# Specific git ref
mlflow run https://github.com/org/my-ml-project.git \
  --version v0.5.0 \
  -P data_version=v1.0.0
```

## 6. Model Registry 단계별 전이

```python
import mlflow

client = mlflow.MlflowClient()

# 1. Production 후보 모델 검증
model_version = client.get_model_version("my-model", version=5)
metrics = client.get_run(model_version.run_id).data.metrics

assert metrics["test_accuracy"] >= 0.85, "Accuracy gate failed"
assert metrics["fairness_gap"] <= 0.05, "Fairness gate failed"

# 2. Staging → Production 전이
client.transition_model_version_stage(
    name="my-model",
    version=5,
    stage="Production",
    archive_existing_versions=True,  # 기존 Production은 Archived로
)

# 3. 배포 트리거 (CI/CD에서)
```

## 7. CI/CD 통합 (GitHub Actions)

```yaml
# .github/workflows/train.yml
name: Train Model
on:
  workflow_dispatch:
    inputs:
      data_version:
        required: true
        default: "v1.0.0"
      learning_rate:
        required: false
        default: "0.001"

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: conda-incubator/setup-miniconda@v3
        with:
          environment-file: conda.yaml
      - name: Login to MLflow
        run: |
          echo "MLFLOW_TRACKING_URI=${{ secrets.MLFLOW_URI }}" >> $GITHUB_ENV
          echo "MLFLOW_TRACKING_TOKEN=${{ secrets.MLFLOW_TOKEN }}" >> $GITHUB_ENV
      - name: Train
        env:
          GIT_COMMIT: ${{ github.sha }}
          ENV: ${{ github.ref == 'refs/heads/main' && 'staging' || 'dev' }}
        run: |
          mlflow run . \
            -P data_version=${{ github.event.inputs.data_version }} \
            -P learning_rate=${{ github.event.inputs.learning_rate }}
```

## 8. 체크리스트

- [ ] `MLproject`에 모든 entry point 정의
- [ ] 환경 파일 1개 이상 (conda.yaml / Dockerfile)
- [ ] Seed 모든 random source에 적용 (random / numpy / torch / tf)
- [ ] `mlflow.set_tag("git_commit", ...)` 로 git SHA 기록
- [ ] `mlflow.log_params` 로 모든 하이퍼파라미터
- [ ] `mlflow.log_metric` 로 per-epoch + final 메트릭
- [ ] Model signature + input example 등록
- [ ] Production 전이 전 게이트 코드로 검증
- [ ] 데이터 버전을 tag로 기록 (DVC commit hash 등)
- [ ] Notebook은 탐색용, 학습은 `.py` 스크립트로
