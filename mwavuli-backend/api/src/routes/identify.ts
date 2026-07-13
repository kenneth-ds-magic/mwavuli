import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth } from '../auth/plugin';
import { identify, identifyFromBytes } from '../services/identify';

const Organ = z.enum(['whole', 'bark', 'leaf', 'flower', 'fruit']);

export async function identifyRoutes(app: FastifyInstance) {
  // Heavier per-route limit — identification calls an upstream model.
  app.post(
    '/v1/identify',
    {
      preHandler: requireAuth,
      config: { rateLimit: { max: 20, timeWindow: 60_000 } },
    },
    async (req) => {
      const b = parse(
        z
          .object({
            imageUrls: z.array(z.string().url()).max(5).optional(),
            images: z
              .array(
                z.object({
                  organ: Organ.default('whole'),
                  data: z.string().min(1).max(8_000_000),
                  contentType: z.string().default('image/jpeg'),
                }),
              )
              .max(5)
              .optional(),
            organs: z.array(z.string()).optional(),
          })
          .refine(
            (v) => (v.imageUrls?.length ?? 0) > 0 || (v.images?.length ?? 0) > 0,
            { message: 'Provide imageUrls or images' },
          ),
        req.body,
      );

      let result;
      if (b.images?.length) {
        result = await identifyFromBytes(
          b.images.map((img) => ({
            organ: img.organ ?? 'whole',
            data: Buffer.from(img.data, 'base64'),
          })),
        );
      } else if (b.imageUrls?.length) {
        result = await identify(b.imageUrls, b.organs ?? []);
      } else {
        throw badRequest('Provide imageUrls or images');
      }
      return {
        candidates: result.candidates,
        source: result.source,
      };
    },
  );
}
