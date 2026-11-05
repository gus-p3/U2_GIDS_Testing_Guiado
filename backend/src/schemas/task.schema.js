'use strict';
const { z } = require('zod');
const { validateTitle } = require('../tasks/validation');

/** Title rule shared by create and update; delegates to the unit-tested validator. */
const titleSchema = z.unknown().transform((value, ctx) => {
  try {
    return validateTitle(value);
  } catch (error) {
    ctx.addIssue({ code: 'custom', message: error.message });
    return z.NEVER;
  }
});

/** Validates a new task payload. Unknown keys such as ownerId are stripped. */
const createTaskSchema = z.object({
  title: titleSchema,
  // null is accepted like in PATCH: the mobile client sends it for "no description" (BUG-008).
  description: z.string().trim().max(2000).nullable().optional(),
});

/** Validates a partial task update. Unknown keys such as ownerId are stripped. */
const updateTaskSchema = z.object({
  title: titleSchema.optional(),
  description: z.string().trim().max(2000).nullable().optional(),
  completed: z.boolean().optional(),
}).refine((value) => Object.keys(value).length > 0, {
  message: 'At least one field is required.',
});

/** Validates pagination query parameters. */
const listTasksSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/** Validates the task identifier route parameter (cuid-like, bounded length). */
const taskIdParamsSchema = z.object({
  taskId: z.string().regex(/^[a-z0-9]{1,64}$/i, 'Invalid task id.'),
});

module.exports = { createTaskSchema, updateTaskSchema, listTasksSchema, taskIdParamsSchema };
