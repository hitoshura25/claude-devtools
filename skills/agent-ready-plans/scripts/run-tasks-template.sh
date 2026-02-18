#!/usr/bin/env bash
# Auto-generated task runner for aider
# Usage: ./run-tasks.sh [--start N] [--dry-run] [--model MODEL]
#
# Prerequisites:
#   - aider installed (pip install aider-chat)
#   - LMStudio running with model loaded
#   - Git repo clean (no uncommitted changes)

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
export LM_STUDIO_API_KEY=dummy-api-key 
export LM_STUDIO_API_BASE=http://localhost:1234/v1

TASKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TASKS_DIR/../../.." && pwd)"
MANIFEST="$TASKS_DIR/00-manifest.json"
DEFAULT_MODEL="lm_studio/qwen/qwen3-coder-30b"

# Read tooling config from manifest
if [[ -f "$MANIFEST" ]]; then
  LINT_CMD=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('tooling',{}).get('lint_cmd',''))" 2>/dev/null || echo "")
  TEST_CMD=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('tooling',{}).get('test_cmd',''))" 2>/dev/null || echo "")
else
  echo "⚠  No manifest found at $MANIFEST — lint/test auto-validation disabled"
  LINT_CMD=""
  TEST_CMD=""
fi

# ── Parse Arguments ────────────────────────────────────────────
START_TASK=1
DRY_RUN=false
MODEL="${DEFAULT_MODEL}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --start) START_TASK="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --api-base) API_BASE="$2"; shift 2 ;;
    --lint-cmd) LINT_CMD="$2"; shift 2 ;;
    --test-cmd) TEST_CMD="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Run Tasks ──────────────────────────────────────────────────
cd "$PROJECT_ROOT"

TASK_FILES=($(ls "$TASKS_DIR"/[0-9][0-9]-task-*.md 2>/dev/null | sort))
TOTAL=${#TASK_FILES[@]}

if [[ $TOTAL -eq 0 ]]; then
  echo "❌  No task files found in $TASKS_DIR"
  exit 1
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  Task Runner — $TOTAL tasks queued"
echo "║  Model: $MODEL"
echo "║  Starting from task: $START_TASK"
if [[ -n "$LINT_CMD" ]]; then
  echo "║  Lint: $LINT_CMD (auto-lint ON)"
fi
if [[ -n "$TEST_CMD" ]]; then
  echo "║  Test: $TEST_CMD (auto-test ON)"
fi
echo "╚══════════════════════════════════════════════╝"
echo ""

SUCCEEDED=0

for TASK_FILE in "${TASK_FILES[@]}"; do
  BASENAME=$(basename "$TASK_FILE")
  TASK_NUM=$(echo "$BASENAME" | grep -oE '^[0-9]+' | sed 's/^0*//')

  if [[ "$TASK_NUM" -lt "$START_TASK" ]]; then
    echo "⏭  Skipping $BASENAME (before start task)"
    continue
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "▶  Running: $BASENAME ($TASK_NUM/$TOTAL)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$DRY_RUN" == true ]]; then
    echo "   [DRY RUN] Would execute aider with $BASENAME"
    continue
  fi

  AIDER_ARGS=(
    --model "$MODEL"
    --no-show-model-warnings
    --no-git
    --message-file "$TASK_FILE"
    --yes
  )

  # Add lint with auto-lint if configured
  if [[ -n "$LINT_CMD" ]]; then
    AIDER_ARGS+=(--lint-cmd "$LINT_CMD" --auto-lint)
  fi

  # Add test with auto-test if configured
  if [[ -n "$TEST_CMD" ]]; then
    AIDER_ARGS+=(--test-cmd "$TEST_CMD" --auto-test)
  fi

  aider "${AIDER_ARGS[@]}"

  AIDER_EXIT=$?
  if [[ $AIDER_EXIT -ne 0 ]]; then
    echo ""
    echo "⚠  aider exited with code $AIDER_EXIT on $BASENAME"
    echo "   Lint/test likely failed and aider could not auto-fix."
    echo "   Fix the issue and re-run with: ./run-tasks.sh --start $TASK_NUM"
    exit 1
  fi

  SUCCEEDED=$((SUCCEEDED + 1))
  echo "✅  Completed: $BASENAME (lint ✓ test ✓)"
done

echo ""
echo "═══════════════════════════════════════════════"
echo "  All $SUCCEEDED tasks completed successfully!"
echo "═══════════════════════════════════════════════"
