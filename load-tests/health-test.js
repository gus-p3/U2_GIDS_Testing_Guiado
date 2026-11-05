// PDF §10: small, authorized load test. Run ONLY against the local test API:
//   k6 run -e BASE_URL=http://127.0.0.1:3100 load-tests/health-test.js
// Stop condition: thresholds abort the run as a failure if errors exceed 1 %
// or p95 latency exceeds 500 ms.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    // Override with -e P95_MS=2 for the practice exercise (stricter threshold).
    http_req_duration: [`p(95)<${__ENV.P95_MS || 500}`],
  },
};

export default function () {
  const response = http.get(`${__ENV.BASE_URL}/health`);

  check(response, {
    'health returns 200': (r) => r.status === 200,
  });

  sleep(1);
}
