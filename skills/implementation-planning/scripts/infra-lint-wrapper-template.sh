#!/usr/bin/env bash
# Infrastructure lint wrapper for aider's --auto-lint
#
# Why this exists:
# aider appends every edited filename to the lint command. For infrastructure
# tasks that create Dockerfiles and compose files alongside Python code, a single
# lint command can't handle all file types. This wrapper routes each file to the
# right linter based on its name/extension:
#
#   Dockerfile*, *.dockerfile  →  hadolint (Dockerfile best-practice linter)
#   *compose*.yml, *compose*.yaml  →  docker compose config (syntax validation)
#   *.py, *.pyi                →  ruff (Python linter, via RUFF_BIN)
#   anything else              →  skipped silently
#
# hadolint reports violations as errors; the small model's reflection loop will
# fix them. docker compose config validates syntax without starting containers.
#
# Usage in manifest (per-task lint_cmd for infrastructure tasks):
#   "lint_cmd": "./docs/plans/my-tasks/infra-lint.sh"
#
# aider calls it as:
#   ./infra-lint.sh services/airflow-ingestion/Dockerfile \
#                   services/airflow-ingestion/deployment/airflow.compose.yml
#
# Prerequisites:
#   - hadolint must be installed (brew install hadolint / apt-get install hadolint)
#   - docker compose must be available
#   - Ruff is optional; only needed if Python files appear alongside infra files

# ── Configuration ──────────────────────────────────────────────
# Set RUFF_BIN if the project uses Python alongside the infra files.
# Leave as empty string to skip Python linting from this wrapper.
# Examples:
#   RUFF_BIN="ruff"
#   RUFF_BIN="uv run --project services/airflow-ingestion ruff"
RUFF_BIN="__RUFF_BIN__"

# ── Route files to appropriate linters ────────────────────────
EXIT_CODE=0

dockerfiles=()
compose_files=()
py_files=()

for f in "$@"; do
  basename=$(basename "$f")
  case "$basename" in
    Dockerfile|Dockerfile.*|*.dockerfile)
      dockerfiles+=("$f")
      ;;
    *compose*.yml|*compose*.yaml|docker-compose.yml|docker-compose.yaml)
      compose_files+=("$f")
      ;;
    *.py|*.pyi)
      py_files+=("$f")
      ;;
    # All other files (requirements.txt, .gitkeep, etc.) are silently skipped.
  esac
done

# ── Lint Dockerfiles with hadolint ─────────────────────────────
if [[ ${#dockerfiles[@]} -gt 0 ]]; then
  if ! command -v hadolint > /dev/null 2>&1; then
    echo "❌ hadolint is not installed. Install it before running infrastructure tasks."
    echo "   macOS:  brew install hadolint"
    echo "   Linux:  apt-get install -y hadolint"
    echo "           or: curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint && chmod +x /usr/local/bin/hadolint"
    exit 1
  fi
  echo "🔍 Linting Dockerfiles with hadolint..."
  if ! hadolint "${dockerfiles[@]}"; then
    EXIT_CODE=1
  fi
fi

# ── Validate compose files with docker compose config ─────────
if [[ ${#compose_files[@]} -gt 0 ]]; then
  for cf in "${compose_files[@]}"; do
    echo "🔍 Validating compose file: $cf"
    if ! docker compose -f "$cf" config --quiet 2>&1; then
      EXIT_CODE=1
    fi
  done
fi

# ── Lint Python files with ruff (if configured) ────────────────
if [[ ${#py_files[@]} -gt 0 && -n "$RUFF_BIN" ]]; then
  echo "🔍 Linting Python files with ruff..."
  if ! $RUFF_BIN check --fix "${py_files[@]}"; then
    EXIT_CODE=1
  fi
fi

exit $EXIT_CODE
