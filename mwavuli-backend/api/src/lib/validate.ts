import { ZodSchema } from 'zod';
import { badRequest } from './errors';

export function parse<T>(schema: ZodSchema<T>, data: unknown): T {
  const r = schema.safeParse(data);
  if (!r.success) {
    const msg = r.error.issues
      .map((i) => `${i.path.join('.') || '(root)'}: ${i.message}`)
      .join('; ');
    throw badRequest(msg);
  }
  return r.data;
}
