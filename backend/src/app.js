'use strict';
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const pinoHttp = require('pino-http');
const { env, getAllowedOrigins } = require('./config');
const { errorHandler } = require('./middleware/error.middleware');
const { createAuthRouter } = require('./routes/auth.routes');
const taskRoutes = require('./routes/task.routes');

/**
 * Builds an Express application. Tests may lower the auth rate limit to exercise it.
 *
 * @param {{authLimit?: number}} [options] - Optional overrides.
 * @returns {import('express').Express} Configured application.
 */
function createApp({ authLimit = env.AUTH_RATE_LIMIT_MAX } = {}) {
  const app = express();
  const allowedOrigins = getAllowedOrigins();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '20kb' }));
  app.use(
    cors({
      origin(origin, callback) {
        // No Origin can occur for native apps and local command-line clients.
        if (
          !origin ||
          allowedOrigins.has(origin) ||
          origin.startsWith('http://localhost:') ||
          origin.startsWith('http://127.0.0.1:')
        ) {
          return callback(null, true);
        }
        return callback(new Error('Origin not allowed.'));
      },
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }),
  );
  app.use(
    pinoHttp({
      // Keep test output readable; production/dev still log every request.
      enabled: env.NODE_ENV !== 'test',
      redact: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.body.password',
        'req.body.refreshToken',
        'req.query.token',
      ],
      serializers: {
        req(request) {
          return { method: request.method, url: request.url };
        },
      },
    }),
  );

  app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));
  app.use('/api/v1/auth', createAuthRouter({ authLimit }));
  app.use('/api/v1/tasks', taskRoutes);
  app.use(errorHandler);
  return app;
}

const app = createApp();

module.exports = { app, createApp };
