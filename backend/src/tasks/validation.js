'use strict';

/** Maximum number of characters allowed in a task title. */
const MAX_TITLE_LENGTH = 120;

/**
 * Trims and validates a task title.
 *
 * @param {unknown} value - Untrusted title input.
 * @returns {string} The validated title.
 * @throws {TypeError} When the title is not valid.
 */
function validateTitle(value) {
  if (typeof value !== 'string') {
    throw new TypeError('Enter a valid title.');
  }
  const title = value.trim();
  if (title.length < 1 || title.length > MAX_TITLE_LENGTH) {
    throw new TypeError('Enter a valid title.');
  }
  return title;
}

module.exports = { validateTitle, MAX_TITLE_LENGTH };
