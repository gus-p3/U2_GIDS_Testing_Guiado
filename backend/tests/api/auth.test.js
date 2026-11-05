'use strict';
/**
 * PDF §8 (password boundaries) and §9 step 6 (expired tokens, refresh rotation,
 * reuse detection, logout, logout-all) plus broken-authentication checks.
 */
const jwt = require('jsonwebtoken');
const request = require('supertest');
const { app } = require('../../src/app');
const { env } = require('../../src/config');
const {
  TEST_PASSWORD,
  uniqueEmail,
  createTestUser,
  trackEmail,
  cleanupTestUsers,
  disconnect,
  prisma,
} = require('../helpers');

afterAll(async () => {
  await cleanupTestUsers();
  await disconnect();
});

const register = (email, password) =>
  request(app).post('/api/v1/auth/register').send({ email, password });
const login = (email, password) =>
  request(app).post('/api/v1/auth/login').send({ email, password });
const refresh = (refreshToken) =>
  request(app).post('/api/v1/auth/refresh').send({ refreshToken });
const listTasks = (accessToken) =>
  request(app).get('/api/v1/tasks').set('Authorization', `Bearer ${accessToken}`);

describe('refresh-token lifecycle', () => {
  test('rotation returns a different refresh token', async () => {
    const initial = await createTestUser();
    const response = await refresh(initial.refreshToken);
    expect(response.status).toBe(200);
    expect(response.body.refreshToken).not.toBe(initial.refreshToken);
  });

  test('reuse of an old token revokes the newer token of the same family', async () => {
    const initial = await createTestUser();
    const rotated = await refresh(initial.refreshToken);
    expect(rotated.status).toBe(200);

    expect((await refresh(initial.refreshToken)).status).toBe(401);
    expect((await refresh(rotated.body.refreshToken)).status).toBe(401);
  });

  test('logout makes the refresh token unusable', async () => {
    const tokens = await createTestUser();
    const logout = await request(app)
      .post('/api/v1/auth/logout')
      .send({ refreshToken: tokens.refreshToken });
    expect(logout.status).toBe(204);
    expect((await refresh(tokens.refreshToken)).status).toBe(401);
  });

  test('logout-all revokes every session of the user, but not other users', async () => {
    const user = await createTestUser();
    const second = await login(user.email, TEST_PASSWORD);
    const bystander = await createTestUser();

    const response = await request(app)
      .post('/api/v1/auth/logout-all')
      .set('Authorization', `Bearer ${user.accessToken}`);
    expect(response.status).toBe(204);

    expect((await refresh(user.refreshToken)).status).toBe(401);
    expect((await refresh(second.body.refreshToken)).status).toBe(401);
    expect((await refresh(bystander.refreshToken)).status).toBe(200);
  });

  test('logout-all requires authentication', async () => {
    const response = await request(app).post('/api/v1/auth/logout-all');
    expect(response.status).toBe(401);
  });

  test('a random, never-issued refresh token is rejected', async () => {
    expect((await refresh('x'.repeat(64))).status).toBe(401);
  });
});

describe('broken authentication: invalid, expired and forged access tokens', () => {
  let userId;
  beforeAll(async () => {
    const user = await createTestUser();
    userId = (await prisma.user.findUnique({ where: { email: user.email } })).id;
  });

  const sign = (payload, secret = env.JWT_ACCESS_SECRET, options = {}) =>
    jwt.sign(payload, secret, {
      algorithm: 'HS256',
      issuer: 'task-manager-api',
      audience: 'task-manager-client',
      ...options,
    });

  test('a correctly signed, current token is accepted (control case)', async () => {
    expect((await listTasks(sign({ sub: userId, type: 'access' }, undefined, { expiresIn: '5m' }))).status).toBe(200);
  });

  test('an expired access token is rejected', async () => {
    const expired = sign(
      { sub: userId, type: 'access', exp: Math.floor(Date.now() / 1000) - 60 },
    );
    expect((await listTasks(expired)).status).toBe(401);
  });

  test('a token signed with the wrong secret is rejected', async () => {
    const forged = sign({ sub: userId, type: 'access' }, 'not-the-real-secret-but-long-enough-123', { expiresIn: '5m' });
    expect((await listTasks(forged)).status).toBe(401);
  });

  test('an unsigned alg=none token is rejected', async () => {
    const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
    const body = Buffer.from(
      JSON.stringify({ sub: userId, type: 'access', iss: 'task-manager-api', aud: 'task-manager-client' }),
    ).toString('base64url');
    expect((await listTasks(`${header}.${body}.`)).status).toBe(401);
  });

  test('a token of the wrong type is rejected', async () => {
    expect((await listTasks(sign({ sub: userId, type: 'refresh' }, undefined, { expiresIn: '5m' }))).status).toBe(401);
  });

  test('a token for another audience is rejected', async () => {
    const token = sign({ sub: userId, type: 'access' }, undefined, { expiresIn: '5m', audience: 'other-client' });
    expect((await listTasks(token)).status).toBe(401);
  });

  test.each([['Bearer'], ['Basic abc'], ['Bearer a b'], ['token-without-scheme']])(
    'a malformed Authorization header %p is rejected',
    async (header) => {
      const response = await request(app).get('/api/v1/tasks').set('Authorization', header);
      expect(response.status).toBe(401);
    },
  );
});

describe('login failures do not reveal which accounts exist', () => {
  test('unknown email and wrong password produce the same response', async () => {
    const user = await createTestUser();
    const wrongPassword = await login(user.email, 'definitely-not-the-password');
    const unknownEmail = await login(uniqueEmail('ghost'), 'definitely-not-the-password');

    expect(wrongPassword.status).toBe(401);
    expect(unknownEmail.status).toBe(401);
    expect(wrongPassword.body).toEqual(unknownEmail.body);
  });

  test('registering the same email twice returns 409', async () => {
    const user = await createTestUser();
    const again = await register(user.email, TEST_PASSWORD);
    expect(again.status).toBe(409);
  });

  test('email is normalised so case variants cannot create duplicate accounts', async () => {
    const email = uniqueEmail('case');
    trackEmail(email);
    expect((await register(email, TEST_PASSWORD)).status).toBe(201);
    expect((await register(email.toUpperCase(), TEST_PASSWORD)).status).toBe(409);
  });
});

describe('password boundary values (PDF §8 practice exercise)', () => {
  // Synthetic passwords only. Policy: 12..72 characters (bcrypt only uses 72 bytes, see BUG-003).
  test.each([
    ['empty', 400, ''],
    ['just under minimum (11)', 400, 'p'.repeat(11)],
    ['minimum valid length (12)', 201, 'p'.repeat(12)],
    ['typical value', 201, 'correct-horse-battery'],
    ['maximum valid length (72)', 201, 'p'.repeat(72)],
    ['just over maximum (73)', 400, 'p'.repeat(73)],
    ['wrong type (number)', 400, 123456789012],
  ])('%s -> %i', async (_name, expected, password) => {
    const email = uniqueEmail('pw');
    trackEmail(email);
    const response = await register(email, password);
    expect(response.status).toBe(expected);
  });

  test('passwords that differ only after byte 72 are not interchangeable (BUG-003 regression)', async () => {
    const email = uniqueEmail('bcrypt');
    trackEmail(email);
    const base = 'b'.repeat(72);
    const registration = await register(email, `${base}X`);
    if (registration.status === 400) return; // Policy rejects > 72 bytes: the ambiguity cannot happen.
    expect(registration.status).toBe(201);
    expect((await login(email, `${base}Y`)).status).toBe(401);
  });

  test('multi-byte characters count as bytes, not characters, against the 72-byte limit', async () => {
    const email = uniqueEmail('utf8');
    trackEmail(email);
    // 37 x "ñ" = 37 characters but 74 UTF-8 bytes.
    expect((await register(email, 'ñ'.repeat(37))).status).toBe(400);
  });
});
