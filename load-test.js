import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
    stages: [
        { duration: '1m', target: 10 },   // Ramp up to 10 users over 1 minute
        { duration: '3m', target: 10 },   // Stay at 10 users for 3 minutes
        { duration: '1m', target: 50 },   // Ramp up to 50 users
        { duration: '3m', target: 50 },   // Stay at 50 users for 3 minutes
        { duration: '1m', target: 100 },  // Ramp up to 100 users
        { duration: '2m', target: 100 },  // Stay at 100 users for 2 minutes
        { duration: '1m', target: 0 },    // Ramp down to 0 users
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
        errors: ['rate<0.1'],              // Error rate should be below 10%
    },
};

const BASE_URL = 'https://family-tree-backend-sws1.onrender.com';

export default function () {
    // Test 1: Ping endpoint
    let pingRes = http.get(`${BASE_URL}/ping`);
    check(pingRes, {
        'ping status is 200': (r) => r.status === 200,
        'ping response time < 200ms': (r) => r.timings.duration < 200,
    }) || errorRate.add(1);

    sleep(1);

    // Test 2: Get persons (public endpoint)
    let personsRes = http.get(`${BASE_URL}/public/persons`);
    check(personsRes, {
        'persons status is 200': (r) => r.status === 200,
        'persons response time < 500ms': (r) => r.timings.duration < 500,
    }) || errorRate.add(1);

    sleep(1);

    // Test 3: Login attempt (should fail without valid credentials, but tests the endpoint)
    let loginPayload = JSON.stringify({
        email: 'test@example.com',
        password: 'testpassword123',
    });

    let loginParams = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    let loginRes = http.post(`${BASE_URL}/login`, loginPayload, loginParams);
    check(loginRes, {
        'login endpoint responds': (r) => r.status === 401 || r.status === 200,
        'login response time < 1000ms': (r) => r.timings.duration < 1000,
    }) || errorRate.add(1);

    sleep(1);
}

export function handleSummary(data) {
    return {
        'load-test-summary.json': JSON.stringify(data, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true }),
    };
}

function textSummary(data, options) {
    const indent = options?.indent || '';
    const enableColors = options?.enableColors || false;

    let summary = `\n${indent}Load Test Summary\n`;
    summary += `${indent}${'='.repeat(50)}\n\n`;

    // Test duration
    summary += `${indent}Duration: ${(data.state.testRunDurationMs / 1000).toFixed(2)}s\n`;

    // HTTP metrics
    if (data.metrics.http_reqs) {
        summary += `${indent}Total Requests: ${data.metrics.http_reqs.values.count}\n`;
        summary += `${indent}Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)}/s\n`;
    }

    if (data.metrics.http_req_duration) {
        summary += `\n${indent}Response Times:\n`;
        summary += `${indent}  Avg: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
        summary += `${indent}  Min: ${data.metrics.http_req_duration.values.min.toFixed(2)}ms\n`;
        summary += `${indent}  Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
        summary += `${indent}  P95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
        summary += `${indent}  P99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
    }

    // HTTP status codes
    if (data.metrics.http_req_failed) {
        const failRate = (data.metrics.http_req_failed.values.rate * 100).toFixed(2);
        summary += `\n${indent}Failed Requests: ${failRate}%\n`;
    }

    // Custom error rate
    if (data.metrics.errors) {
        const errorRate = (data.metrics.errors.values.rate * 100).toFixed(2);
        summary += `${indent}Error Rate: ${errorRate}%\n`;
    }

    summary += `\n${indent}${'='.repeat(50)}\n`;

    return summary;
}
