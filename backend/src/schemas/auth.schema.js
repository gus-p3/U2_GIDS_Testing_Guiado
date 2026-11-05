'use strict';
const { z } = require('zod');

/**
 * bcrypt only hashes the first 72 bytes of its input, so longer passwords would make
 * every suffix after byte 72 interchangeable (BUG-003). The limit is in UTF-8 bytes.
 */
const BCRYPT_MAX_BYTES = 72;
const withinBcryptLimit = (value) => Buffer.byteLength(value, 'utf8') <= BCRYPT_MAX_BYTES;
const bcryptLimitMessage = `Password must be at most ${BCRYPT_MAX_BYTES} bytes.`;

/** Validates registration credentials. */
const registerSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(12).refine(withinBcryptLimit, bcryptLimitMessage),
});

/** Validates login credentials. */
const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1).refine(withinBcryptLimit, bcryptLimitMessage),
});

/** Validates an opaque refresh token. */
const refreshSchema = z.object({
  refreshToken: z.string().min(20).max(200),
});

module.exports = { registerSchema, loginSchema, refreshSchema, BCRYPT_MAX_BYTES };
