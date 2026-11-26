/**
 * k6 Load Test — 정상 부하 성능 검증
 *
 * 사용법:
 *   1. 이 파일을 프로젝트의 load-tests/ 디렉토리에 복사
 *   2. BASE_URL, 시나리오, 임계값을 프로젝트에 맞게 수정
 *   3. 실행: k6 run load-tests/k6-load-test.js
 *   4. CI: k6 run --out json=results.json load-tests/k6-load-test.js
 *
 * 목적: 예상 최대 부하에서 SLO 기준을 충족하는지 검증
 */
import http from "k6/http";
import { check, sleep, group } from "k6";
import { Rate, Trend } from "k6/metrics";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Custom metrics
const errorRate = new Rate("errors");
const apiLatency = new Trend("api_latency", true);

export const options = {
  // Ramp-up → Steady → Peak → Ramp-down
  stages: [
    { duration: "2m", target: 50 },   // Ramp up to normal load
    { duration: "5m", target: 50 },   // Steady state
    { duration: "2m", target: 100 },  // Peak load
    { duration: "2m", target: 100 },  // Sustain peak
    { duration: "1m", target: 0 },    // Ramp down
  ],

  // SLO-based thresholds (modify for your SLO)
  thresholds: {
    http_req_duration: [
      "p(50)<200",    // Median < 200ms
      "p(95)<500",    // P95 < 500ms
      "p(99)<1000",   // P99 < 1s
    ],
    http_req_failed: ["rate<0.01"],   // Error rate < 1%
    errors: ["rate<0.01"],
  },
};

export default function () {
  // Scenario 1: List resources
  group("GET /api/v1/items", () => {
    const res = http.get(`${BASE_URL}/api/v1/items?page=1&size=20`);
    check(res, {
      "list: status 200": (r) => r.status === 200,
      "list: has data": (r) => JSON.parse(r.body).data !== undefined,
    });
    errorRate.add(res.status !== 200);
    apiLatency.add(res.timings.duration);
  });

  sleep(1);

  // Scenario 2: Get single resource
  group("GET /api/v1/items/:id", () => {
    const res = http.get(`${BASE_URL}/api/v1/items/1`);
    check(res, {
      "detail: status 200": (r) => r.status === 200,
    });
    errorRate.add(res.status !== 200);
    apiLatency.add(res.timings.duration);
  });

  sleep(Math.random() * 2);  // Random think time

  // Scenario 3: Create resource (POST)
  group("POST /api/v1/items", () => {
    const payload = JSON.stringify({
      name: `load-test-${Date.now()}`,
      description: "k6 load test item",
    });
    const params = {
      headers: { "Content-Type": "application/json" },
    };
    const res = http.post(`${BASE_URL}/api/v1/items`, payload, params);
    check(res, {
      "create: status 201": (r) => r.status === 201,
    });
    errorRate.add(res.status !== 201);
    apiLatency.add(res.timings.duration);
  });

  sleep(1);
}
