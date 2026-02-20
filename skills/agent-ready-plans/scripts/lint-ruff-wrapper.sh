#!/usr/bin/env bash
# Lint wrapper for aider's --auto-lint
#
# Why this exists:
# aider appends every edited filename to the lint command, including non-Python
# files like requirements.txt, .gitkeep, Dockerfile, etc. Ruff will try to parse
# these as Python and report syntax errors the small model can never fix.
#
# Even with ruff's include/exclude config, explicitly passed files bypass those
# filters (ruff always lints files passed directly on the command line). The
# force-exclude setting helps but has edge cases with monorepo subdirectories.
#
# This wrapper filters to only .py/.pyi files and runs ruff with --fix so that
# trivially fixable issues (import sorting, unused imports) are auto-corrected
# instead of being sent to the small model.
#
# Usage in manifest:
#   "lint_cmd": "./path/to/lint.sh"
#
# aider will call it as:
#   ./lint.sh services/foo/bar.py services/foo/requirements.txt
# and the wrapper will only pass bar.py to ruff.

# ── Configuration ──────────────────────────────────────────────
# Set this to the path to the ruff binary, relative to project root.
# Examples:
#   RUFF_BIN="ruff"                                          # ruff on PATH
#   RUFF_BIN="services/airflow-ingestion/.venv/bin/ruff"     # venv binary
#   RUFF_BIN="uv run --project services/foo ruff"            # uv-managed
RUFF_BIN="__RUFF_BIN__"

# ── Filter to Python files only ────────────────────────────────
py_files=()
for f in "$@"; do
  if [[ "$f" == *.py || "$f" == *.pyi ]]; then
    py_files+=("$f")
  fi
done

# If no Python files were edited, nothing to lint — exit success
if [[ ${#py_files[@]} -eq 0 ]]; then
  exit 0
fi

# ── Run ruff with --fix ───────────────────────────────────────
# --fix auto-corrects trivially fixable issues (import sorting, unused imports)
# so the small model doesn't waste attempts on style fixes it can't resolve.
exec $RUFF_BIN check --fix "${py_files[@]}"
