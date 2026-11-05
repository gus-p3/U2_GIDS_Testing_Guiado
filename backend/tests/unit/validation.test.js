'use strict';
/**
 * PDF §4 (unit tests in isolation) + §8 (boundary values and equivalence partitions).
 * No network, no database: pure input -> output checks.
 */
const { validateTitle, MAX_TITLE_LENGTH } = require('../../src/tasks/validation');

describe('validateTitle', () => {
  test('trims a valid title', () => {
    expect(validateTitle('  Plan tests  ')).toBe('Plan tests');
  });

  test('rejects a blank title', () => {
    expect(() => validateTitle('   ')).toThrow('Enter a valid title.');
  });

  test('rejects a title longer than the limit', () => {
    expect(() => validateTitle('a'.repeat(121))).toThrow();
  });

  // §8 boundary table for a title of 1..120 characters.
  describe.each([
    ['empty', '', 'reject'],
    ['whitespace only', '   ', 'reject'],
    ['minimum valid length', 'a', 'accept'],
    ['typical valid title', 'Plan tests', 'accept'],
    ['maximum valid length (120)', 'a'.repeat(MAX_TITLE_LENGTH), 'accept'],
    ['just over maximum (121)', 'a'.repeat(MAX_TITLE_LENGTH + 1), 'reject'],
    ['120 chars after trimming surrounding spaces', `  ${'b'.repeat(120)}  `, 'accept'],
  ])('partition: %s', (_name, input, expected) => {
    test(`${expected}s ${JSON.stringify(input.length > 20 ? `${input.length} chars` : input)}`, () => {
      if (expected === 'accept') {
        expect(validateTitle(input)).toBe(input.trim());
      } else {
        expect(() => validateTitle(input)).toThrow('Enter a valid title.');
      }
    });
  });

  // Wrong types arriving from untrusted JSON must be rejected safely (no crash, same message).
  test.each([42, null, undefined, true, {}, ['Plan tests']])('rejects non-string input %p', (input) => {
    expect(() => validateTitle(input)).toThrow(TypeError);
  });
});
