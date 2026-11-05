'use strict';
/**
 * Resets the synthetic end-to-end account in the *test* database:
 * creates it if missing and deletes all of its tasks and refresh tokens.
 * Run before every Flutter integration journey: npm run seed:test
 */
const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');

const url = process.env.DATABASE_URL || '';
if (!url.split('/').pop().split('?')[0].endsWith('_test')) {
  console.error('Refusing to seed: DATABASE_URL is not a *_test database.');
  process.exit(1);
}

const email = process.env.E2E_TEST_EMAIL;
const password = process.env.E2E_TEST_PASSWORD;
if (!email || !email.endsWith('@example.test') || !password) {
  console.error('E2E_TEST_EMAIL must be an @example.test address and E2E_TEST_PASSWORD must be set.');
  process.exit(1);
}

async function main() {
  const prisma = new PrismaClient();
  try {
    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.user.upsert({
      where: { email },
      update: { passwordHash },
      create: { email, passwordHash },
    });
    const tasks = await prisma.task.deleteMany({ where: { ownerId: user.id } });
    const tokens = await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
    console.info(`Seeded ${email}: removed ${tasks.count} tasks and ${tokens.count} refresh tokens.`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error('Seed failed:', error.message);
  process.exit(1);
});
