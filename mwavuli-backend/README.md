# mwavuli — backend (Phase 3)

The server side for mwavuli: a PostgreSQL/PostGIS database, a Fastify + TypeScript
REST API, a serverless image pipeline (EXIF stripping + thumbnails), and a
moderation dashboard. Built to the security & privacy requirements in the brief.

> **Full design**: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) ·
> **API reference**: [`infra/openapi.yaml`](infra/openapi.yaml)

## What's here

```
db/migrations/        PostGIS schema (001–010): identity, trees, exact-location
                      table (RLS-protected), social, gamification, moderation,
                      GDPR jobs, rate-limit, RLS policies, seed
api/                  Fastify + TypeScript API (auth, trees/feed, identify,
                      comments, social, GDPR export/erasure, moderation)
serverless/image-pipeline/  S3-triggered Lambda: strip EXIF/GPS + thumbnails (sharp)
admin/index.html      Self-contained moderation dashboard (calls the admin API)
infra/                docker-compose, OpenAPI spec
docs/ARCHITECTURE.md  System design + threat model + security spec
.github/workflows/    CI (API tests + PostGIS) and CD (image build + migrate)
```

## Quickstart (Docker)

```bash
docker compose -f infra/docker-compose.yml up --build
# → Postgres+PostGIS (5432), Redis (6379), API (8080), Adminer (8081)
# The `migrate` service applies all migrations before the API starts.
```

Create an admin and open the dashboard:

```bash
cd api
MIGRATE_DATABASE_URL=postgres://postgres:postgres@localhost:5432/mwavuli \
  npm run create-admin -- admin@mwavuli.app admin 'StrongPass123' 'Admin'
# then log in via POST /v1/auth/login, and open admin/index.html in a browser.
```

## Quickstart (manual)

```bash
# 1. Postgres 16 + PostGIS running, database `mwavuli` created.
cd api && npm install
cp .env.example .env            # fill in DATABASE_URL, JWT_SECRET, S3_*

# 2. Migrate as a privileged role (creates extensions + the app role).
MIGRATE_DATABASE_URL=postgres://postgres:...@localhost/mwavuli npm run migrate

# 3. Run.
npm run dev                     # API on :8080
npm run worker                  # (separately) GDPR purges + badge awards
```

## Security posture (summary)

- **Location privacy** — exact GPS lives in `tree_exact_locations`, a separate
  table with **row-level security**; the public API only ever returns the fuzzy
  point (±500 m). Exact-coordinate reads require ownership/staff and are written
  to `audit_log`.
- **EXIF/GPS stripping** — done server-side in the image pipeline (and on-device
  in the app) before any photo is public.
- **Rate limiting** — global + per-route (tight on `/identify`, `/me/export`).
- **Moderation** — reports → admin dashboard → actions, all audited.
- **GDPR** — data export (JSON/CSV) and 30-day erasure with a worker.
- **COPPA** — 13+ gate at registration; only birth *year* is stored.
- **TLS everywhere**; passwords hashed with scrypt; refresh tokens stored hashed
  and rotated.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full model and threat
analysis.

## Testing & CI

```bash
cd api
npm install
npm run typecheck
npm run migrate            # against a Postgres/PostGIS (use MIGRATE_DATABASE_URL)
npm test                   # unit (password, fuzz, csv) + integration (Fastify inject + PostGIS)
```

Integration tests exercise the privacy model directly: they assert the feed
exposes only fuzzy points, that a non-owner gets **403** on exact coordinates
(RLS), that private trees stay out of the public feed, and that a staff `hide`
action removes a reported tree. GitHub Actions (`.github/workflows/`) runs the
API suite against a `postgis/postgis` service, typechecks the image pipeline,
and (on `main`) builds/pushes the API image and runs prod migrations.

## Deploy to production

1. **Provision** managed Postgres 16 + PostGIS (RDS / Cloud SQL) with storage
   encryption, an S3-compatible bucket pair (private uploads + public
   derivatives), and — for horizontal scale — Redis for shared rate-limit
   counters.
2. **Secrets** — set `DATABASE_URL` (the `mwavuli_app` role), `JWT_SECRET`,
   `S3_*`, and `PLANTNET_API_KEY`, plus a privileged `MIGRATE_DATABASE_URL` for
   migrations. Change the default `mwavuli_app` password from migration 009.
3. **API** — `api/Dockerfile` builds a runnable image; the `deploy` workflow
   pushes it to GHCR and runs `npm run migrate` against prod on merge to `main`.
   Drop in your platform's one-line rollout (ECS / Fly.io / Cloud Run) where marked.
4. **Image pipeline** — `cd serverless/image-pipeline && sam build && sam deploy`
   wires the S3 `ObjectCreated` trigger (see its README for IAM + sharp binary).
5. **Worker** — schedule `npm run worker` (cron / ECS Scheduled Task) for GDPR
   purges and badge awards.
6. **Dashboard** — host `admin/index.html` as a static file and point it at the API.

TLS terminates at the load balancer / CDN; keep the uploads bucket private
(Block Public Access) so only EXIF-stripped derivatives are ever served.

## How the Flutter app connects

The Flutter app's `core/` services point at these endpoints: `ApiClient` →
`/v1/*` (auth, feed, trees, `/v1/me/*`), identification → `/v1/identify`, the
offline queue flushes to `POST /v1/trees`, and photos upload to the presigned S3
URLs returned there. Build the app with
`--dart-define=MWAVULI_API=https://api.mwavuli.app`.
