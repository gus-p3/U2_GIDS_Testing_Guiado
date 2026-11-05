'use strict';
/**
 * Runs before every test file. Forces the test environment and refuses to run
 * against any database whose name does not end in `_test`, so a suite can never
 * create or delete data in a development or production database.
 */
const path = require('node:path');
const dotenv = require('dotenv');

process.env.NODE_ENV = 'test';
dotenv.config({ path: path.join(__dirname, '..', '.env.test'), quiet: true });

const url = process.env.DATABASE_URL || '';
const dbName = url.split('/').pop().split('?')[0];
if (!dbName.endsWith('_test')) {
  throw new Error(`Refusing to run tests: database "${dbName}" is not a *_test database.`);
}
