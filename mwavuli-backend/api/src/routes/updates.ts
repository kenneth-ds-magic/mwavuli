import type { FastifyInstance } from 'fastify';
import { runAs } from '../db';
import { parse } from '../lib/validate';
import { z } from 'zod';

export async function updatesRoutes(app: FastifyInstance) {
  // Public endpoint for mobile app startup version checks
  app.get('/v1/app/version', async (req) => {
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT app_version, link, release_notes, updated_at
           FROM updates
          ORDER BY id DESC
          LIMIT 1`,
      );
      if (!rows[0]) {
        return {
          appVersion: '0.1.0',
          link: 'http://129.205.2.218/mwavuli/download/app-latest.apk',
          releaseNotes: 'Initial release of Mwavuli',
        };
      }
      return {
        appVersion: rows[0].app_version as string,
        link: rows[0].link as string,
        releaseNotes: (rows[0].release_notes as string) ?? '',
        updatedAt: rows[0].updated_at,
      };
    });
  });

  // Endpoint to post or update a new version release
  app.post('/v1/updates', async (req) => {
    const b = parse(
      z.object({
        appVersion: z.string().min(1),
        link: z.string().min(1),
        releaseNotes: z.string().default(''),
      }),
      req.body,
    );

    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO updates (app_version, link, release_notes)
         VALUES ($1, $2, $3)
         ON CONFLICT (app_version) DO UPDATE
            SET link = EXCLUDED.link,
                release_notes = EXCLUDED.release_notes,
                updated_at = now()
         RETURNING id, app_version, link, release_notes, updated_at`,
        [b.appVersion, b.link, b.releaseNotes],
      );

      return {
        ok: true,
        update: {
          id: rows[0].id,
          appVersion: rows[0].app_version,
          link: rows[0].link,
          releaseNotes: rows[0].release_notes,
          updatedAt: rows[0].updated_at,
        },
      };
    });
  });
}
