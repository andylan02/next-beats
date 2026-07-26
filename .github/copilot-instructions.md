# Copilot instructions for NextBeats

Purpose
- Short guide for Copilot sessions to understand repository layout, build/test/lint commands, and repository-specific conventions.

Build / Test / Lint (how to run)
- Install: `pnpm install` (project uses pnpm@10.x as package manager).
- Dev: `pnpm run dev` (local Next dev server).
- Build: `pnpm run build` (runs `prisma generate && next build`).
- Start (production): `pnpm run start` (expects a built app).

Prisma and DB helpers
- Prisma push (create schema): `pnpm run prisma.push`.
- Seed: `pnpm run prisma.seed`.
- Studio: `pnpm run prisma.studio`.
- Reset (dev): `pnpm run prisma.reset` (push --force-reset + seed).
- Note: The app normalizes DATABASE_URL with `lib/database-url.ts` to enforce TLS (`sslmode=verify-full`) unless explicitly set to `sslmode=disable`.

Lint & formatting
- Format: `pnpm run format` (prettier).
- Lint: `pnpm run lint`.
- Lint (fix): `pnpm run lint:fix`.
- To lint a single file: `pnpm run lint -- path/to/file` (or call `eslint path/to/file`).
- To format a single file: `pnpm run format -- path/to/file` (or `prettier --write path/to/file`).

End-to-end tests (Playwright)
- E2E script: `pnpm run test:e2e` (runs `playwright test`).
- Run a single Playwright test file: `pnpm run test:e2e -- tests/track-page.spec.ts`.
- Run a single test title or grep: `pnpm run test:e2e -- -g "pattern"` or use Playwright flags as needed.
- Playwright config: `playwright.config.ts` uses `tests/` and a webServer that runs `pnpm dev --port 3002` with `beats-user` cookie pre-seeded for e2e auth. Default baseURL: `http://localhost:3002`.

High-level architecture (big picture)
- Next.js 16.3 App Router project (app/). The repo uses the new App Router features: server components, Server Functions (app/api/* routes), Cache Components and cache tags (`revalidateTag`) and Instant Navigations features.
- React 19 + React Compiler: heavy use of server components with selective client boundaries. Many pages live under `app/(app)` and use server-rendered data.
- Database layer: Prisma 7 with a generated client under `generated/prisma/`. The DB client is initialized in `lib/db.ts` which uses a Prisma adapter (`@prisma/adapter-pg` by default) and calls normalizeDatabaseUrl to enforce TLS semantics.
- Audio engine & domain code: `lib/audio/*` contains the procedural synthesis and scheduler for the music player — application logic and deterministic audio profiles live there.
- Tests: Playwright E2E tests in `tests/` exercise Instant Navigation and user flows. They rely on a seeded browser cookie `beats-user` (value `e2e`) in `playwright.config.ts`.

Key repo-specific conventions
- Next.js differences: This project uses a newer, nonstandard Next.js release. Read `node_modules/next/dist/docs/` before making changes; this repo includes an `AGENTS.md` warning: "This is NOT the Next.js you know".
- Server-only modules: Files that import `server-only` (or are under app route handlers) are intended to run only on the server. Example: `lib/db.ts` begins with `import 'server-only'` and must not be used from client components.
- Prisma adapters: The code uses adapter classes (e.g., `PrismaPg`) instead of direct `PrismaClient` connection strings. To run locally without Postgres, follow README instructions to swap the provider to SQLite and switch to `@prisma/adapter-better-sqlite3` and `better-sqlite3`.
- Database URL normalization: `lib/database-url.ts` rewrites `sslmode` to `verify-full` unless `disable` is explicit — tests/CI may supply `sslmode=disable` in workflows.
- Session cookie / test cookie: The application uses a cookie named `beats-user` for the user session; Playwright e2e config seeds that cookie value as `e2e`. When writing tests or helper scripts, reuse this cookie name to simulate auth.
- Tests expect the dev server to run on port `3002` (Playwright webServer config). Use `pnpm dev --port 3002` for E2E runs or let Playwright start the server via its webServer config.
- Generated client: Prisma generator outputs to `generated/prisma/` and the code imports from `@/generated/prisma/client`.

Where to look first
- README.md: Getting started and feature overview.
- playwright.config.ts and tests/: E2E flow, baseURL, and cookie behavior.
- lib/db.ts and lib/database-url.ts: DB initialization and TLS behavior.
- prisma/schema.prisma: data model and indexes.

Agent / Assistant notes for safe edits
- Avoid moving server-only code to client components. If a function imports `server-only` or Prisma, keep it server-only.
- When changing the DB provider, update both `lib/db.ts` and any `prisma` seed/helpers that reference adapters.
- E2E tests rely on a seeded cookie; changes to auth/session handling require updating tests or test config.

Files consulted
- README.md, package.json, prisma/schema.prisma, lib/db.ts, lib/database-url.ts, playwright.config.ts, AGENTS.md, CLAUDE.md

CI / GitHub Actions
- Workflow path: `.github/workflows/playwright.yml` (Playwright E2E). It: checks out code, enables pnpm, starts a Postgres service, pushes Prisma schema, seeds the DB, builds the app, installs Playwright browsers, starts the dev server on port 3002, runs `pnpm run test:e2e`, and uploads the Playwright report.
- Run in CI: push or open a PR against `main`, or use "Run workflow" in Actions -> Playwright E2E.
- Environment: workflow uses `DATABASE_URL` pointing at the service Postgres; update if the DB name/credentials change.
- Artifacts & logs: the workflow uploads the Playwright report and (on failure) the dev server log `/tmp/next.log`.
- Secrets: If using hosted DB or private secrets, add them to repo Secrets and reference them in the workflow (e.g., `DATABASE_URL`).

Local reproduction script
- Script path: `scripts/ci-e2e.sh` (added to repo). It reproduces the CI steps locally using Docker and assumes `docker` is installed and available.
- Basic usage (Unix-like shell):
  - Make executable once: `chmod +x scripts/ci-e2e.sh`
  - Run: `scripts/ci-e2e.sh`
- What the script does:
  1. Starts a temporary Postgres 15 container (`nextbeats-ci-postgres`) on localhost:5432.
  2. Waits for Postgres to accept connections.
  3. Exports `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/test` and runs `pnpm install --frozen-lockfile`, `pnpm run prisma.push`, `pnpm run prisma.seed`, `pnpm run build`.
  4. Installs Playwright browsers, starts the dev server at port 3002 in background, waits for `/login` to be available, runs `pnpm run test:e2e`, prints results and uploads (copies) the Playwright report into `playwright-report/` locally.
  5. Cleans up: kills the dev server and removes the Postgres container.
- Notes/requirements:
  - Requires Docker to run Postgres locally.
  - The script is for Unix-like shells (macOS, Linux, WSL, Git Bash). Windows native users can run it under WSL.
  - If you already have Postgres on 5432, set `HOST_POSTGRES=true` and the script will skip starting the container; instead ensure `DATABASE_URL` is set in your environment.

CI / local notes and caveats
- Playwright config expects the dev server on port `3002` and seeds a cookie `beats-user` for E2E auth. If ports or cookie names change, update `playwright.config.ts` and `scripts/ci-e2e.sh` accordingly.
- Database TLS: `lib/database-url.ts` forces `sslmode=verify-full` unless `sslmode=disable`. CI uses local Postgres without TLS; ensure `sslmode=disable` in env if connecting to a non-TLS DB.
- When changing Prisma adapters or the datasource provider, update both `lib/db.ts`, `prisma/seed.ts`, and the CI script/workflow.

Questions / next steps
- Configure MCP servers? This repo has Playwright E2E — would you like an MCP server configured for Playwright (recommended)?

If anything else should be added (extra CI steps, matrix testing, or Windows-native scripts), say which area and Copilot will update this file.

---

Repository-specific agent rules (added from session histroy findings)

1) Network & git push guidance
- Before attempting a push, always show a short checklist: branch name, local HEAD (git --no-pager log --oneline -n1), and list of files changed.
- Retry commands to suggest when a push fails: `git -c http.postBuffer=524288000 -c http.lowSpeedLimit=0 -c http.lowSpeedTime=999999 push origin <branch>` and SSH fallback `git@github.com:owner/repo.git`.
- If network errors repeat (curl 28 or connection reset), prefer offering the commit details and instructing the user to push locally rather than auto-retrying.

2) Local-commit transparency
- For multi-file changes, add a short commit-summary block in the assistant response (commit SHA, brief bullet list of added/modified files, and whether pushed). Offer explicit actions: Show commit details / Retry push / Wait.
- Do not retry pushes without user confirmation after a failed attempt.

3) Duplicate-question handling
- If the user asks the same small factual question within a short time window (e.g., "今天是星期几?", "CLI 版本?"), respond once with a concise canonical answer including timestamp, then reference the prior reply for duplicates instead of repeating investigation commands.
- When the user requests re-checks (e.g., /version), rerun the canonical check commands but otherwise cite the stored answer.

4) Model & CLI-check commands
- Use these canonical checks when asked about environment or availability:
  - `/model` — list or select model
  - `/version` — show CLI version
  - `/update` — check for CLI updates
  - `/login` — confirm authentication
- When answering "can I use it?" include: current date (ISO), CLI version, active model, and note if network-dependent operations may fail.

---

Would you like any wording changes or additional rules to be included?


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->
