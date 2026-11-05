'use strict';
const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const { registerSchema, loginSchema, refreshSchema } = require('../schemas/auth.schema');
const authService = require('../services/auth.service');

const asyncRoute = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);

/** Builds a rate limiter that answers with a safe, consistent 429 body. */
const limiter = (max) =>
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: max,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: { code: 'RATE_LIMITED', message: 'Too many requests. Try again later.' } },
  });

/**
 * Builds the auth router. `authLimit` caps register/login attempts per 15 minutes;
 * refresh and logout allow three times that amount.
 *
 * @param {{authLimit: number}} options - Rate-limit configuration.
 * @returns {import('express').Router} Auth router.
 */
function createAuthRouter({ authLimit }) {
  const router = express.Router();

  /** Registers an account and returns its initial token pair. */
  router.post(
    '/register',
    limiter(authLimit),
    validate(registerSchema, 'body'),
    asyncRoute(async (req, res) => {
      res.status(201).json(await authService.register(req.body));
    }),
  );

  /** Authenticates an account and returns its token pair. */
  router.post(
    '/login',
    limiter(authLimit),
    validate(loginSchema, 'body'),
    asyncRoute(async (req, res) => {
      res.json(await authService.login(req.body));
    }),
  );

  /** Rotates a refresh token and returns the replacement pair. */
  router.post(
    '/refresh',
    limiter(authLimit * 3),
    validate(refreshSchema, 'body'),
    asyncRoute(async (req, res) => {
      res.json(await authService.refresh(req.body.refreshToken));
    }),
  );

  /** Revokes the refresh-token family supplied by the client. */
  router.post(
    '/logout',
    limiter(authLimit * 3),
    validate(refreshSchema, 'body'),
    asyncRoute(async (req, res) => {
      await authService.logout(req.body.refreshToken);
      res.status(204).end();
    }),
  );

  /** Revokes all refresh tokens belonging to the authenticated user. */
  router.post(
    '/logout-all',
    requireAuth,
    asyncRoute(async (req, res) => {
      await authService.logoutAll(req.user.id);
      res.status(204).end();
    }),
  );

  return router;
}

module.exports = { createAuthRouter };
