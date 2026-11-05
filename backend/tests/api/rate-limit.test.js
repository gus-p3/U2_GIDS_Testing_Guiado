'use strict';
/**
 * PDF §9 step 5: a small, authorized rate-limit run against the local test app.
 * A dedicated app instance with a low limit keeps the run tiny (4 requests).
 */
const request = require('supertest');
const { createApp } = require('../../src/app');
const { uniqueEmail, disconnect } = require('../helpers');

afterAll(disconnect);

describe('login rate limiting', () => {
  test('returns a safe 429 after the configured number of attempts', async () => {
    const limitedApp = createApp({ authLimit: 3 });
    const attempt = () =>
      request(limitedApp)
        .post('/api/v1/auth/login')
        .send({ email: uniqueEmail('rl'), password: 'wrong-password-for-test' });

    for (let i = 0; i < 3; i += 1) {
      expect((await attempt()).status).toBe(401);
    }
    const blocked = await attempt();

    expect(blocked.status).toBe(429);
    expect(blocked.body).toEqual({
      error: { code: 'RATE_LIMITED', message: 'Too many requests. Try again later.' },
    });
    expect(blocked.headers.ratelimit).toBeDefined();
  });

  test('the refresh endpoint is limited too', async () => {
    const limitedApp = createApp({ authLimit: 1 });
    const attempt = () =>
      request(limitedApp).post('/api/v1/auth/refresh').send({ refreshToken: 'r'.repeat(40) });
    for (let i = 0; i < 3; i += 1) {
      expect((await attempt()).status).toBe(401);
    }
    expect((await attempt()).status).toBe(429);
  });
});
