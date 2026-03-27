#!/usr/bin/env bash
# Docker smoke test template for aider's --auto-test
#
# Why this exists:
# Infrastructure tasks (Dockerfile + compose) can't be verified with unit tests.
# The meaningful correctness check is: does the container build, start, and
# respond on its health endpoint? This script encodes that check reliably.
#
# This template is copied into the tasks folder during scaffold (Step 3) and
# customised for the specific service. Two variables must be set before use:
#   COMPOSE_FILE   — path to the self-contained test compose file (not the
#                    production compose, which assumes external services)
#   HEALTH_URL     — URL to poll for readiness (e.g. http://localhost:8080/health)
#
# The test compose file should be self-contained: it must include the service
# under test AND any infrastructure it depends on (MinIO, RabbitMQ, etc.) as
# local services, so the test requires only Docker — not a running shared stack.
#
# On failure the script exits non-zero. aider treats this as a test failure and
# enters its reflection loop to fix the Dockerfile/compose. The cleanup trap
# ensures containers are always removed, even when the script fails partway.
#
# Usage in manifest (per-task test_command):
#   "test_command": "bash docs/plans/my-tasks/smoke-test-my-service.sh"
#
# Prerequisites:
#   - Docker must be installed and the daemon must be running
#   - The test compose file must exist at COMPOSE_FILE before this script runs

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
# Set these two variables when copying this template for a specific service.

# Path to the self-contained test compose file, from project root.
# This compose file includes the service under test AND its dependencies.
# It must NOT rely on external networks or pre-running shared services.
COMPOSE_FILE="__COMPOSE_FILE__"

# Health endpoint to poll for readiness. The script waits until this URL
# returns HTTP 200 before running assertions.
HEALTH_URL="__HEALTH_URL__"

# Maximum seconds to wait for the service to become healthy.
TIMEOUT_SECONDS=120

# ── Project root detection ─────────────────────────────────────
# This script is invoked from the project root by the runner. Keep it that way.
PROJECT_ROOT="$(pwd)"

# ── Cleanup trap ──────────────────────────────────────────────
# Always tear down containers, whether the test passes or fails.
# -v removes named volumes so each run starts with a clean state.
cleanup() {
  echo "🧹 Tearing down test containers..."
  docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" down -v --remove-orphans \
    2>/dev/null || true
  # Do NOT run `docker system prune` here. It deletes build cache that the
  # runner's independent verification needs for its rebuild. The compose down
  # above is sufficient for cleaning up containers and volumes.
}
trap cleanup EXIT

# ── Pre-flight check ──────────────────────────────────────────
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker daemon is not running. Start Docker and re-run."
  echo "   This test requires Docker to build and start the service container."
  exit 1
fi

if [[ ! -f "$PROJECT_ROOT/$COMPOSE_FILE" ]]; then
  echo "❌ Test compose file not found: $COMPOSE_FILE"
  echo "   The small model must create this file before the smoke test can run."
  exit 1
fi

# ── Build and start ───────────────────────────────────────────
echo "🐳 Building and starting services from $COMPOSE_FILE..."
set +e
docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" up -d --build \
  --wait --wait-timeout "$TIMEOUT_SECONDS" 2>&1
WAIT_EXIT=$?
set -e

if [[ $WAIT_EXIT -ne 0 ]]; then
  echo "❌ docker compose up --wait failed (exit $WAIT_EXIT)."
  echo "   Container status:"
  docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" ps -a 2>/dev/null || true
  echo "   Container logs (last 80 lines per service):"
  docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" logs --tail=80 2>/dev/null || true
  exit 1
fi

echo "✅ All health checks passed per compose file declarations."

# ── Readiness poll ────────────────────────────────────────────
# Poll the health endpoint explicitly in case the compose healthcheck window
# is tight or the service doesn't declare a healthcheck.
echo "⏳ Polling $HEALTH_URL for readiness (timeout: ${TIMEOUT_SECONDS}s)..."
ELAPSED=0
until curl -sf "$HEALTH_URL" > /dev/null 2>&1; do
  if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
    echo "❌ Service did not become ready at $HEALTH_URL within ${TIMEOUT_SECONDS}s."
    echo "   Container logs:"
    docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" logs --tail=50
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "✅ Service is responding at $HEALTH_URL."

# ── Assertions ────────────────────────────────────────────────
# Verify the health endpoint returns HTTP 200 and a healthy status.
echo "🔍 Running smoke test assertions..."

HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$HEALTH_URL")
if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "❌ Health endpoint returned HTTP $HTTP_STATUS (expected 200)."
  docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" logs --tail=50
  exit 1
fi

echo "✅ Smoke test passed — service started, responded 200 on health endpoint."

# Cleanup runs via trap on exit.
