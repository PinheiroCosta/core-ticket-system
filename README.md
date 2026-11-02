# Core Ticket System

Core Ticket System is an open-source, self-hosted ticket management engine designed to be installed independently by each organization. This repository contains the initial development foundation; application features will be added incrementally.

## Architecture

The project uses Astro as a static site generator for the administrative interface and Cloudflare Pages Functions as an independent REST API under `/api/v1`. The frontend does not depend on Astro SSR or on backend rendering. Cloudflare D1 stores relational data, while private Cloudflare R2 objects are referenced by attachment metadata in D1.

## Technology stack

- Astro and TypeScript (strict mode)
- Cloudflare Pages and Pages Functions
- Wrangler for local development and deployment
- Cloudflare D1 (SQLite) and R2
- Vitest, ESLint, and Prettier

## Prerequisites

- Node.js 22.23.4 or newer
- npm 10 or newer
- Wrangler authentication is only required for deployment or access to remote Cloudflare resources

## Local installation

```sh
npm install
npm run dev
```

`npm run dev` starts Astro's static frontend development server. To exercise the built site together with Pages Functions locally:

```sh
npm run build
npm run dev:pages
```

The Pages preview is available at the URL printed by Wrangler. The health endpoint is `GET /api/v1/health` and returns `{"status":"ok"}`.

## Development commands

| Command                | Purpose                                               |
| ---------------------- | ----------------------------------------------------- |
| `npm run dev`          | Start the Astro frontend development server           |
| `npm run build`        | Create the static production build in `dist/`         |
| `npm run dev:pages`    | Serve `dist/` and `functions/` through Wrangler Pages |
| `npm run format`       | Format supported source and configuration files       |
| `npm run format:check` | Verify formatting without changing files              |
| `npm run lint`         | Run ESLint                                            |
| `npm run typecheck`    | Run Astro and TypeScript checks                       |
| `npm test`             | Run Vitest                                            |

## Database migrations

The local D1 database is configured by `wrangler.toml` and is stored in `.wrangler/state`. Apply the initial migration locally with:

```sh
npx wrangler d1 migrations apply DB --local
npx wrangler d1 execute DB --local --command "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;"
```

Apply migrations to a configured production database only after replacing the placeholder `database_id` in `wrangler.toml`:

```sh
npx wrangler d1 migrations apply DB --remote
```

Authentication flows that persist user records must normalize email addresses before writes (trim + lowercase) so stored values remain canonical and match the database's case-insensitive uniqueness guarantees.

Never commit production identifiers, credentials, or secrets. Create the R2 bucket separately and replace the placeholder `bucket_name` before deployment.

## Cloudflare configuration

`wrangler.toml` declares the Pages bindings:

- `DB`: D1 database binding
- `STORAGE`: R2 bucket binding

Local development does not require Cloudflare credentials. Wrangler creates local D1 and R2 emulation state as needed. For production, configure an independent D1 database and R2 bucket for each installation, set their identifiers in the Wrangler configuration (or deployment environment), and deploy the `dist/` directory with the root-level `functions/` directory.

No authentication, user registration, ticket operations, messaging, uploads, notifications, or external integrations are implemented in this foundation.
