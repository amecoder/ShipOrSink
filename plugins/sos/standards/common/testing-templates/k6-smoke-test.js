/**
 * k6 Smoke Test — 기본 동작 검증
 *
 * 사용법:
 *   1. 이 파일을 프로젝트의 load-tests/ 디렉토리에 복사
 *   2. BASE_URL을 프로젝트에 맞게 수정
 *   3. 실행: k6 run load-tests/k6-smoke-test.js
 *
 * 목적: 배포 후 기본 엔드포인트가 정상 동작하는지 빠르게 확인
 * VU: 1~3명, 시간: 1분
 */
import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

export const options = {
  stages: [
    { duration: "30s", target: 3 },  // Ramp up to 3 VUs
    { duration: "30s", target: 0 },  // Ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"],   // 95% of requests < 500ms
    http_req_failed: ["rate<0.01"],     // Error rate < 1%
  },
};

export default function () {
  // Health check
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    "health: status 200": (r) => r.status === 200,
  });

  // Main API endpoint (modify for your project)
  const apiRes = http.get(`${BASE_URL}/api/v1/status`);
  check(apiRes, {
    "api: status 200": (r) => r.status === 200,
    "api: response time < 500ms": (r) => r.timings.duration < 500,
  });

  sleep(1);
}
