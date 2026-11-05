'use strict';
const request = require('supertest');
const { app } = require('../../src/app');
const { disconnect } = require('../helpers');

afterAll(disconnect);

describe('health endpoint (smoke)', () => {
  test('returns a healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });

  test('does not advertise the framework and sends safe headers', async () => {
    const response = await request(app).get('/health');
    expect(response.headers['x-powered-by']).toBeUndefined();
    expect(response.headers['x-content-type-options']).toBe('nosniff');
  });
});
