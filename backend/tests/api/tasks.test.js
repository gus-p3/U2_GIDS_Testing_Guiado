'use strict';
/**
 * PDF §6 (API + integrated backend) and §9 (negative behavior / security basics).
 * Runs against the isolated *_test PostgreSQL database through Supertest.
 */
const request = require('supertest');
const { app } = require('../../src/app');
const {
  createTestUser,
  createTestUserAndGetToken,
  createTask,
  cleanupTestUsers,
  disconnect,
  prisma,
} = require('../helpers');

afterAll(async () => {
  await cleanupTestUsers();
  await disconnect();
});

const auth = (token) => ({ Authorization: `Bearer ${token}` });

describe('task API security (PDF §6)', () => {
  test('rejects task creation without authentication', async () => {
    const response = await request(app).post('/api/v1/tasks').send({ title: 'Plan tests' });
    expect(response.status).toBe(401);
  });

  test('rejects an empty title', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: '   ' });
    expect(response.status).toBe(400);
  });

  test('does not let one user read another user task', async () => {
    const owner = await createTestUserAndGetToken();
    const stranger = await createTestUserAndGetToken();
    const taskId = await createTask(owner, 'Private task');

    const response = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(stranger));

    expect([403, 404]).toContain(response.status);
  });
});

describe('practice exercise §6: invalid id, missing title, cross-user update', () => {
  let ownerToken;
  let strangerToken;
  let taskId;

  beforeAll(async () => {
    ownerToken = await createTestUserAndGetToken();
    strangerToken = await createTestUserAndGetToken();
    taskId = await createTask(ownerToken, 'Owner original title');
  });

  test('a malformed task id is rejected with 400 before touching the database', async () => {
    const response = await request(app)
      .get(`/api/v1/tasks/${encodeURIComponent("1' OR '1'='1")}`)
      .set(auth(ownerToken));
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  test('an over-long task id is rejected with 400', async () => {
    const response = await request(app).get(`/api/v1/tasks/${'a'.repeat(65)}`).set(auth(ownerToken));
    expect(response.status).toBe(400);
  });

  test('a well-formed id that does not exist returns 404', async () => {
    const response = await request(app)
      .get('/api/v1/tasks/cnotarealtaskid000000000')
      .set(auth(ownerToken));
    expect(response.status).toBe(404);
  });

  test('foreign and missing tasks get the identical response (no existence disclosure)', async () => {
    const foreign = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(strangerToken));
    const missing = await request(app)
      .get('/api/v1/tasks/cnotarealtaskid000000000')
      .set(auth(strangerToken));
    expect(foreign.status).toBe(missing.status);
    expect(foreign.body).toEqual(missing.body);
  });

  test('a missing title is rejected', async () => {
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(ownerToken))
      .send({ description: 'No title here' });
    expect(response.status).toBe(400);
    expect(response.body.error.details[0].field).toBe('title');
  });

  test('a user cannot update another user task, and the task stays unchanged', async () => {
    const attempt = await request(app)
      .patch(`/api/v1/tasks/${taskId}`)
      .set(auth(strangerToken))
      .send({ title: 'Hacked by B', completed: true });
    expect(attempt.status).toBe(404);

    const ownerView = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(ownerToken));
    expect(ownerView.body.item.title).toBe('Owner original title');
    expect(ownerView.body.item.completed).toBe(false);
  });

  test('a user cannot delete another user task', async () => {
    const attempt = await request(app).delete(`/api/v1/tasks/${taskId}`).set(auth(strangerToken));
    expect(attempt.status).toBe(404);
    expect(await prisma.task.count({ where: { id: taskId } })).toBe(1);
  });

  test("the list endpoint only returns the caller's tasks", async () => {
    const strangerList = await request(app).get('/api/v1/tasks').set(auth(strangerToken));
    expect(strangerList.status).toBe(200);
    expect(strangerList.body.items.some((t) => t.id === taskId)).toBe(false);
  });

  test('the owner can complete and then delete their own task', async () => {
    const done = await request(app)
      .patch(`/api/v1/tasks/${taskId}`)
      .set(auth(ownerToken))
      .send({ completed: true });
    expect(done.status).toBe(200);
    expect(done.body.item.completed).toBe(true);

    const removed = await request(app).delete(`/api/v1/tasks/${taskId}`).set(auth(ownerToken));
    expect(removed.status).toBe(204);
  });
});

describe('negative input (PDF §9 step 1)', () => {
  let token;
  beforeAll(async () => {
    token = await createTestUserAndGetToken();
  });

  test.each([
    ['number title', { title: 42 }],
    ['null title', { title: null }],
    ['array title', { title: ['Plan tests'] }],
    ['121-char title', { title: 'a'.repeat(121) }],
    ['2001-char description', { title: 'ok', description: 'd'.repeat(2001) }],
  ])('rejects %s with a safe 400', async (_name, body) => {
    const response = await request(app).post('/api/v1/tasks').set(auth(token)).send(body);
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(JSON.stringify(response.body)).not.toMatch(/prisma|stack|at \w+ \(/i);
  });

  test('accepts a title at the exact 120-char maximum', async () => {
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: 'm'.repeat(120) });
    expect(response.status).toBe(201);
  });

  test('accepts description: null on create, the shape the mobile app sends (BUG-008)', async () => {
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: 'No details', description: null });
    expect(response.status).toBe(201);
    expect(response.body.item.description).toBeNull();
  });

  test('rejects malformed JSON with 400 and no stack trace', async () => {
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .set('Content-Type', 'application/json')
      .send('{"title": "unterminated');
    expect(response.status).toBe(400);
    expect(JSON.stringify(response.body)).not.toMatch(/at \w+ \(|node_modules/);
  });

  test('rejects an oversized body (> 20 kb) with 413', async () => {
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: 'big', description: 'x'.repeat(25 * 1024) });
    expect(response.status).toBe(413);
  });

  test.each([['0'], ['101'], ['-1'], ["1' OR '1'='1"]])('rejects pagination limit=%s', async (limit) => {
    const response = await request(app)
      .get(`/api/v1/tasks?limit=${encodeURIComponent(limit)}`)
      .set(auth(token));
    expect(response.status).toBe(400);
  });

  test('a PATCH with no fields is rejected', async () => {
    const id = await createTask(token, 'Patch target');
    const response = await request(app).patch(`/api/v1/tasks/${id}`).set(auth(token)).send({});
    expect(response.status).toBe(400);
  });
});

describe('injection-looking and markup-like input (PDF §9 steps 2-3)', () => {
  test('an SQL-injection-looking title is stored as plain text and leaks nothing', async () => {
    const attacker = await createTestUserAndGetToken();
    const victim = await createTestUserAndGetToken();
    await createTask(victim, 'Victim secret');
    const payload = "' OR '1'='1";

    const created = await request(app).post('/api/v1/tasks').set(auth(attacker)).send({ title: payload });
    expect(created.status).toBe(201);
    expect(created.body.item.title).toBe(payload);

    const list = await request(app).get('/api/v1/tasks').set(auth(attacker));
    expect(list.body.items).toHaveLength(1);
    expect(list.body.items[0].title).toBe(payload);
  });

  test('markup is returned verbatim as JSON data, never as HTML', async () => {
    const token = await createTestUserAndGetToken();
    const markup = '<script>alert(1)</script>';
    const created = await request(app).post('/api/v1/tasks').set(auth(token)).send({ title: markup });
    expect(created.status).toBe(201);
    expect(created.headers['content-type']).toMatch(/application\/json/);
    expect(created.body.item.title).toBe(markup);
  });
});

describe('object property-level authorization (PDF §9 practice exercise)', () => {
  test('ownerId sent on create is ignored; the server derives ownership', async () => {
    const victim = await createTestUser();
    const victimRecord = await prisma.user.findUnique({ where: { email: victim.email } });
    const attacker = await createTestUserAndGetToken();

    const created = await request(app)
      .post('/api/v1/tasks')
      .set(auth(attacker))
      .send({ title: 'Planted task', ownerId: victimRecord.id });
    expect(created.status).toBe(201);
    expect(created.body.item.ownerId).not.toBe(victimRecord.id);

    const victimList = await request(app).get('/api/v1/tasks').set(auth(victim.accessToken));
    expect(victimList.body.items.some((t) => t.title === 'Planted task')).toBe(false);
  });

  test('ownerId sent on update is ignored and ownership is retained', async () => {
    const owner = await createTestUser();
    const ownerRecord = await prisma.user.findUnique({ where: { email: owner.email } });
    const other = await createTestUser();
    const otherRecord = await prisma.user.findUnique({ where: { email: other.email } });
    const taskId = await createTask(owner.accessToken, 'Keep me');

    const response = await request(app)
      .patch(`/api/v1/tasks/${taskId}`)
      .set(auth(owner.accessToken))
      .send({ title: 'Keep me (edited)', ownerId: otherRecord.id });
    expect(response.status).toBe(200);
    expect(response.body.item.ownerId).toBe(ownerRecord.id);

    const stored = await prisma.task.findUnique({ where: { id: taskId } });
    expect(stored.ownerId).toBe(ownerRecord.id);
    const otherView = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(other.accessToken));
    expect(otherView.status).toBe(404);
  });
});
