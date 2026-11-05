'use strict';
/**
 * Shared helpers for API tests. Every user is synthetic (example.test domain)
 * and is deleted, with its tasks and tokens, by `cleanupTestUsers`.
 */
const crypto = require('node:crypto');
const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/task.repository');

const TEST_PASSWORD = 'synthetic-test-password-123';
const createdEmails = new Set();

/** Returns a unique synthetic email address. */
function uniqueEmail(prefix = 'user') {
  return `${prefix}-${crypto.randomUUID()}@example.test`;
}

/**
 * Registers a synthetic user and returns its full token pair.
 *
 * @param {import('express').Express} [target] - App under test.
 * @returns {Promise<{email: string, accessToken: string, refreshToken: string}>}
 */
async function createTestUser(target = app) {
  const email = uniqueEmail();
  const response = await request(target)
    .post('/api/v1/auth/register')
    .send({ email, password: TEST_PASSWORD });
  if (response.status !== 201) {
    throw new Error(`Test user registration failed with ${response.status}`);
  }
  createdEmails.add(email);
  return { email, ...response.body };
}

/** Registers a synthetic user and returns only its access token (name used in the PDF). */
async function createTestUserAndGetToken() {
  return (await createTestUser()).accessToken;
}

/**
 * Creates a task for the owner of `token` and returns its id.
 *
 * @param {string} token - Owner's access token.
 * @param {string} title - Task title.
 * @returns {Promise<string>} Created task id.
 */
async function createTask(token, title) {
  const response = await request(app)
    .post('/api/v1/tasks')
    .set('Authorization', `Bearer ${token}`)
    .send({ title });
  if (response.status !== 201) {
    throw new Error(`Task creation failed with ${response.status}`);
  }
  return response.body.item.id;
}

/** Remembers an email registered outside the helpers so it is cleaned up too. */
function trackEmail(email) {
  createdEmails.add(email);
}

/** Deletes every synthetic user created by this test file (tasks/tokens cascade). */
async function cleanupTestUsers() {
  if (createdEmails.size > 0) {
    await prisma.user.deleteMany({ where: { email: { in: [...createdEmails] } } });
    createdEmails.clear();
  }
}

/** Closes the Prisma connection so Jest can exit cleanly. */
async function disconnect() {
  await prisma.$disconnect();
}

module.exports = {
  TEST_PASSWORD,
  uniqueEmail,
  createTestUser,
  createTestUserAndGetToken,
  createTask,
  trackEmail,
  cleanupTestUsers,
  disconnect,
  prisma,
};
