#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT_DIR=$(pwd)
CONTAINER_NAME="nextbeats-ci-postgres"
DB_URL="postgresql://postgres:postgres@127.0.0.1:5432/test"
PID_FILE=".next.pid"
LOG_FILE="/tmp/next.log"

print() { echo "[ci-e2e] $*"; }

# If HOST_POSTGRES is set, skip starting container
if [ -z "${HOST_POSTGRES:-}" ]; then
  print "Starting Postgres container (${CONTAINER_NAME})..."
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run --name "$CONTAINER_NAME" -e POSTGRES_DB=test -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15

  print "Waiting for Postgres to become ready..."
  for i in {1..60}; do
    if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
      print "Postgres is ready"
      break
    fi
    sleep 1
  done
fi

export DATABASE_URL="$DB_URL"
print "Using DATABASE_URL=$DATABASE_URL"

print "Enabling corepack and preparing pnpm..."
corepack enable || true
corepack prepare pnpm@10.33.0 --activate || true

print "Installing dependencies..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm install --frozen-lockfile
else
  npm exec --yes pnpm -- install --frozen-lockfile
fi

print "Pushing Prisma schema..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm run prisma.push
else
  npm exec --yes pnpm -- run prisma.push
fi

print "Seeding database..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm run prisma.seed
else
  npm exec --yes pnpm -- run prisma.seed
fi

print "Building app..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm run build
else
  npm exec --yes pnpm -- run build
fi

print "Installing Playwright browsers..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm exec playwright install --with-deps
else
  npm exec --yes pnpm -- exec playwright install --with-deps
fi

print "Starting dev server on port 3002..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm dev --port 3002 > "$LOG_FILE" 2>&1 &
else
  npm exec --yes pnpm -- dev --port 3002 > "$LOG_FILE" 2>&1 &
fi
NEXT_PID=$!
echo "$NEXT_PID" > "$PID_FILE"

print "Waiting for /login to become available..."
for i in {1..60}; do
  if curl -sSf http://localhost:3002/login >/dev/null; then
    print "Server is up"
    break
  fi
  sleep 1
done

if ! curl -sSf http://localhost:3002/login >/dev/null; then
  print "Server failed to start, dumping log:" && cat "$LOG_FILE"
  exit 1
fi

print "Running Playwright tests..."
set +e
if command -v pnpm >/dev/null 2>&1; then
  pnpm run test:e2e --reporter=list
else
  npm exec --yes pnpm -- run test:e2e --reporter=list
fi
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
  print "Playwright tests failed (exit $EXIT_CODE). See $LOG_FILE for server logs."
  print "Copying Playwright report to ./playwright-report (if present)"
  mkdir -p "$ROOT_DIR/playwright-report" || true
  if [ -d "$ROOT_DIR/playwright-report" ]; then
    print "playwright-report exists"
  fi
else
  print "Playwright tests passed"
fi

print "Cleaning up..."
if [ -f "$PID_FILE" ]; then
  NEXT_PID=$(cat "$PID_FILE")
  kill "$NEXT_PID" 2>/dev/null || true
  rm -f "$PID_FILE" || true
fi

if [ -z "${HOST_POSTGRES:-}" ]; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

exit $EXIT_CODE
