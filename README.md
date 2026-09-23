Internships browser — Next.js 16 + Tailwind + Drizzle ORM + Postgres (Docker). DB-only; no JSON fallback.

## Stack
- Next.js 16 (App Router, `output: standalone` in `next.config.ts:4`)
- Drizzle ORM + `pg` (`db/schema.ts:1`, `db/index.ts:1`)
- Postgres 16 via Docker (`docker-compose.yml:1`, `Dockerfile:1`)

## Getting Started

```bash
cp .env.example .env        # edit DATABASE_URL if needed
npm install
npm run db:setup            # create DB and sync internships from remote (required)
npm run dev                 # http://localhost:3000 — requires DB
```

## Database + Docker

**Env** (` .env.example:1`, `.env:1` — gitignored, example committed):
```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/intership-helper
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=intership-helper
POSTGRES_PORT=5432
```

**Drizzle** (`drizzle.config.ts:1` reads `DATABASE_URL`):
```bash
npm run db:generate   # drizzle-kit generate — creates ./drizzle/*.sql (already has 0000_real_tattoo.sql)
npm run db:push       # drizzle-kit push — push schema directly (dev, no SQL)
npm run db:migrate    # drizzle-kit migrate — apply generated SQL
npm run db:studio     # drizzle-kit studio --port 4983 — GUI on http://localhost:4983
npm run db:sync       # tsx scripts/sync-internships.ts — fetches SimplifyJobs and Canadian Tech README tables and upserts normalized listings
npm run db:sync:dry   # dry-run without DB writes
```

The production migration image is separate from the Next.js runtime image and contains the
Drizzle CLI plus migration files. Start Postgres, run the one-shot migration container, then
build/start the application:

```bash
docker compose up -d db
docker compose run --rm migrate
docker compose up -d --build app
```

`migrate` exits after applying pending migrations. A non-zero exit means the application should
not be deployed until the migration problem is resolved. It does not run the internship data sync;
run `npm run db:sync` separately when an import is needed.

**Docker** (requires Docker daemon):
```bash
npm run docker:up     # docker compose up --build — starts db (postgres) + app (Next standalone on :3000)
npm run docker:down   # docker compose down
# or manually:
docker compose up -d db             # only postgres on :5432
npx drizzle-kit migrate             # apply migrations
npm run db:sync       # fetch and insert new internships
```

API: `GET /api/internships` (`app/api/internships/route.ts:1`) — DB-only (503 if `DATABASE_URL` not set). Run `npm run db:setup` first.

## Scripts
- `npm run dev` / `build` / `start` / `lint`
- `npm run db:*` / `npm run docker:*` (see above)

## GitHub Actions and homelab deployment

Pull requests and pushes to `main` run the `build` and `tests` checks in
`.github/workflows/ci.yml`. The test command uses `npm run test --if-present`; this
is intentionally a no-op until a test script is added to `package.json`.

After CI passes on `main`, `.github/workflows/deploy.yml` deploys through a self-hosted
runner labeled `self-hosted`. The runner host must have the repository checked out through
the runner, Docker access, and `/opt/internship-helper/.env.production` containing the
production database settings. The workflow starts Postgres, runs the one-shot `migrate`
container, syncs internships, then builds and starts the app.

To verify the runner before merging a deployment change, check that it is online under
**Settings → Actions → Runners** and that its labels include `self-hosted`.
Merging to `main` starts CI first; the production workflow is then triggered only when CI
finishes successfully.

### Production configuration and automatic refresh

The runner must be able to read `/opt/internship-helper/.env.production`. If your
production settings already live elsewhere, set the `PRODUCTION_ENV_FILE` variable
under **Settings → Environments → production → Environment variables** to that
file's absolute path. Keep the file outside the runner checkout, which checkout
cleans before each job. Use `.env.example` as a template and set `POSTGRES_USER`,
`POSTGRES_PASSWORD`, `POSTGRES_DB`, and `POSTGRES_PORT` to the production database's
existing settings. Changing these values does not change credentials in an
already initialized Postgres volume.

A missing env file stops deployment at the configuration check. The Node.js 20
Actions deprecation warning is separate; workflows now use checkout/setup-node v6
(Node.js 24 action runtime), while the application continues to use Node.js 26.
The self-hosted runner must be version 2.329.0 or newer.

The `Sync internships` GitHub Actions workflow runs hourly at 17 minutes past
the hour (UTC), using this server's self-hosted runner. It launches a one-shot
sync container and shares a concurrency group with deployments to prevent
simultaneous imports. The workflow must be merged to `main` and the runner must
stay online. GitHub may delay scheduled jobs. Manual imports are also available
under **Actions → Sync internships → Run workflow**.

Production uses `compose.production.yml` to keep Postgres on this project's
Docker network without publishing port 5432 on the host. Other applications'
containers and networks are not changed.

Start the services locally with:

```bash
docker compose -f docker-compose.yml -f compose.production.yml --env-file /opt/internship-helper/.env.production up -d db
docker compose -f docker-compose.yml -f compose.production.yml --env-file /opt/internship-helper/.env.production run --build --rm migrate
docker compose -f docker-compose.yml -f compose.production.yml --env-file /opt/internship-helper/.env.production run --build --rm sync
docker compose -f docker-compose.yml -f compose.production.yml --env-file /opt/internship-helper/.env.production up -d --build app
```

Inspect scheduled import output in the GitHub Actions run logs.

Imports fetch SimplifyJobs and Canadian Tech listings and update Postgres, which
is what the website reads. Reload the page to see refreshed data. Sync failures
now fail the workflow. Successful runs archive JSON logs under
`/opt/internship-helper/logs`, retaining the most recent 20 archives.
