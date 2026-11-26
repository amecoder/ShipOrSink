"""
Pact Consumer Test Example — Python

사용법:
  1. 이 파일을 tests/contract/ 디렉토리에 복사
  2. 서비스명, API 경로, 요청/응답을 프로젝트에 맞게 수정
  3. pip install pact-python
  4. 실행: pytest tests/contract/ -v
  5. 생성된 pacts/ 디렉토리를 Pact Broker에 업로드

목적: Consumer(호출자)가 기대하는 API 형태를 정의하고,
      Provider(제공자)가 이를 충족하는지 자동 검증
"""
from __future__ import annotations

import pytest
from pact import Consumer, Provider, Like, EachLike, Term


# Consumer: 현재 서비스 이름
# Provider: 호출하는 대상 서비스 이름
pact = Consumer("OrderService").has_pact_with(
    Provider("PaymentService"),
    pact_dir="./pacts",
    log_dir="./pact-logs",
)


class TestPaymentServiceContract:
    """PaymentService API에 대한 Consumer Contract 정의."""

    def test_create_payment(self) -> None:
        """POST /api/payments — 결제 생성 성공."""
        expected_response = {
            "id": Like("pay_abc123"),              # 형식만 검증 (값은 무관)
            "status": Term(r"completed|pending", "completed"),
            "amount": Like(10000),
            "currency": "KRW",
            "created_at": Like("2026-03-14T00:00:00Z"),
        }

        (
            pact
            .given("a valid order exists with id ord_456")
            .upon_receiving("a request to create a payment")
            .with_request(
                method="POST",
                path="/api/payments",
                headers={"Content-Type": "application/json"},
                body={
                    "order_id": "ord_456",
                    "amount": 10000,
                    "currency": "KRW",
                },
            )
            .will_respond_with(
                status=201,
                headers={"Content-Type": "application/json"},
                body=expected_response,
            )
        )

        with pact:
            # Replace with your actual HTTP client call
            import requests
            response = requests.post(
                f"{pact.uri}/api/payments",
                json={"order_id": "ord_456", "amount": 10000, "currency": "KRW"},
            )
            assert response.status_code == 201
            data = response.json()
            assert data["status"] in ("completed", "pending")

    def test_get_payment(self) -> None:
        """GET /api/payments/:id — 결제 조회."""
        (
            pact
            .given("a payment exists with id pay_abc123")
            .upon_receiving("a request to get payment details")
            .with_request(method="GET", path="/api/payments/pay_abc123")
            .will_respond_with(
                status=200,
                body={
                    "id": "pay_abc123",
                    "status": Like("completed"),
                    "amount": Like(10000),
                    "order_id": Like("ord_456"),
                },
            )
        )

        with pact:
            import requests
            response = requests.get(f"{pact.uri}/api/payments/pay_abc123")
            assert response.status_code == 200

    def test_payment_not_found(self) -> None:
        """GET /api/payments/:id — 404 에러."""
        (
            pact
            .given("no payment exists with id pay_nonexistent")
            .upon_receiving("a request for a non-existent payment")
            .with_request(method="GET", path="/api/payments/pay_nonexistent")
            .will_respond_with(
                status=404,
                body={
                    "error": {
                        "code": "PAYMENT_NOT_FOUND",
                        "message": Like("Payment not found"),
                    },
                },
            )
        )

        with pact:
            import requests
            response = requests.get(f"{pact.uri}/api/payments/pay_nonexistent")
            assert response.status_code == 404
