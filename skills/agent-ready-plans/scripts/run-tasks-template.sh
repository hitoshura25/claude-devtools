#!/usr/bin/env bash
# Auto-generated task runner for aider
# Usage: ./run-tasks.sh [--start N] [--dry-run] [--model MODEL]
#
# Prerequisites:
#   - aider installed (pip install aider-chat)
#   - LMStudio running with model loaded
#   - Git repo clean (no uncommitted changes)
#
# Aider flag reference (from https://aider.chat/docs/config/options.html):
#   --lint-cmd CMD    Lint command; aider appends edited filenames to it
#   --auto-lint       Auto-lint after changes (default: TRUE — on by default)
#   --no-auto-lint    Disable auto-lint
#   --test-cmd CMD    Test command; aider runs it as-is (no filenames appended)
#   --auto-test       Auto-test after changes (default: FALSE — must opt in)
#   --message-file F  Send file content as message, process reply, then exit
#   --yes-always      Always say yes to every confirmation
#   --no-git          Disable git integration
#   --no-check-update Skip checking for aider updates on launch

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
export LM_STUDIO_API_KEY=dummy-api-key
export LM_STUDIO_API_BASE=http://localhost:1234/v1

TASKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TASKS_DIR/../../.." && pwd)"
MANIFEST="$TASKS_DIR/00-manifest.json"
LOG_FILE="$TASKS_DIR/run-$(date +%Y%m%d-%H%M%S).log"
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

# Read deferred task list from manifest
DEFERRED_TASKS=""
if [[ -f "$MANIFEST" ]]; then
  DEFERRED_TASKS=$(python3 -c "
import json
m = json.load(open('$MANIFEST'))
deferred = [t['file'] for t in m.get('tasks', []) if t.get('deferred', False)]
print('\n'.join(deferred))
" 2>/dev/null || echo "")
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
    --lint-cmd) LINT_CMD="$2"; shift 2 ;;
    --test-cmd) TEST_CMD="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helper: check if a task file is deferred ───────────────────
is_deferred() {
  local basename="$1"
  echo "$DEFERRED_TASKS" | grep -qF "$basename"
}

# ── Run Tasks ──────────────────────────────────────────────────
cd "$PROJECT_ROOT"

TASK_FILES=($(ls "$TASKS_DIR"/[0-9][0-9]-task-*.md 2>/dev/null | sort))
TOTAL=${#TASK_FILES[@]}

# Count deferred tasks from manifest (includes tasks without .md files yet)
DEFERRED_COUNT=$(echo "$DEFERRED_TASKS" | grep -c '.' || echo 0)
# Count task .md files that actually exist
EXISTING_COUNT=${#TASK_FILES[@]}

if [[ $EXISTING_COUNT -eq 0 && $DEFERRED_COUNT -eq 0 ]]; then
  echo "❌  No task files found in $TASKS_DIR"
  exit 1
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  Task Runner — $EXISTING_COUNT task files + $DEFERRED_COUNT deferred"
echo "║  Model: $MODEL"
echo "║  Starting from task: $START_TASK"
echo "║  Log: $LOG_FILE"
if [[ -n "$LINT_CMD" ]]; then
  echo "║  Lint: $LINT_CMD (auto-lint is ON by default)"
fi
if [[ -n "$TEST_CMD" ]]; then
  echo "║  Test: $TEST_CMD (auto-test ON)"
fi
echo "╚══════════════════════════════════════════════╝"
echo ""

SUCCEEDED=0
DEGRADED=0
DEFERRED_HIT=false

for TASK_FILE in "${TASK_FILES[@]}"; do
  BASENAME=$(basename "$TASK_FILE")
  TASK_NUM=$(echo "$BASENAME" | grep -oE '^[0-9]+' | sed 's/^0*//')

  if [[ "$TASK_NUM" -lt "$START_TASK" ]]; then
    echo "⏭  Skipping $BASENAME (before start task)"
    continue
  fi

  # ── Check pre_validated flag ───────────────────────────────
  PRE_VALIDATED=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$BASENAME'), None)
if task is None:
    sys.exit(0)
print('true' if task.get('pre_validated', False) else 'false')
" 2>/dev/null || echo "unknown")

  if [[ "$PRE_VALIDATED" == "false" ]]; then
    echo ""
    echo "⚠️  WARNING: $BASENAME is not pre_validated in the manifest."
    echo "   Tests were not verified by Claude Code before handoff."
    echo "   The small model may be working with weak or broken tests."
    echo ""
    echo "   To fix: re-run Step 3b (write and validate tests) for this task,"
    echo "   update the manifest with pre_validated=true, and re-run."
    echo ""
    read -r -p "   Continue anyway? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "   Aborted. Fix the task first."
      exit 1
    fi
  fi

  # ── Check if this is a deferred task ───────────────────────
  if is_deferred "$BASENAME"; then
    DEFERRED_HIT=true
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⏸  Deferred: $BASENAME ($TASK_NUM/$TOTAL)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   This task depends on interfaces produced by earlier tasks."
    echo "   Its task doc must be generated from the actual code."
    echo ""
    echo "   To continue:"
    echo "   1. Generate deferred task docs using Claude Code:"
    echo "      Read the manifest's deferred entries and the actual source files,"
    echo "      then create the .md task doc with real signatures and imports."
    echo "   2. Resume the runner:"
    echo "      ./run-tasks.sh --start $TASK_NUM"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Implementation phase complete: $SUCCEEDED tasks succeeded, $DEGRADED degraded"
    echo "  Paused before $((TOTAL - SUCCEEDED - DEGRADED)) deferred task(s)"
    echo "═══════════════════════════════════════════════"
    exit 0
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "▶  Running: $BASENAME ($TASK_NUM/$TOTAL)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$DRY_RUN" == true ]]; then
    echo "   [DRY RUN] Would execute aider with $BASENAME"
    continue
  fi

  # Core aider args
  AIDER_ARGS=(
    --model "$MODEL"
    --no-show-model-warnings
    --no-check-update
    --no-git
    --message-file "$TASK_FILE"
    --yes-always
  )

  # Lint: aider appends edited filenames to lint_cmd, so it must work from project root.
  # Do NOT use 'cd' in lint_cmd — the appended paths will break after the cd.
  if [[ -n "$LINT_CMD" ]]; then
    AIDER_ARGS+=(--lint-cmd "$LINT_CMD" --auto-lint)
  fi

  # Test: aider runs test_cmd as-is (no filenames appended), so 'cd' is safe here.
  if [[ -n "$TEST_CMD" ]]; then
    AIDER_ARGS+=(--test-cmd "$TEST_CMD" --auto-test)
  fi

  # Capture aider output to detect reflection exhaustion
  TASK_LOG="$TASKS_DIR/.task-output-$TASK_NUM.tmp"
  aider "${AIDER_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE" | tee "$TASK_LOG"

  AIDER_EXIT=${PIPESTATUS[0]}

  # ── Check for reflection exhaustion ──────────────────────
  REFLECTIONS_EXHAUSTED=false
  if grep -q "reflections allowed, stopping" "$TASK_LOG" 2>/dev/null; then
    REFLECTIONS_EXHAUSTED=true
  fi
  rm -f "$TASK_LOG"

  # ── Check aider exit code ────────────────────────────────
  if [[ $AIDER_EXIT -ne 0 ]]; then
    echo ""
    echo "❌  aider exited with code $AIDER_EXIT on $BASENAME"
    echo "   Lint/test likely failed and aider could not auto-fix."
    echo "   Fix the issue and re-run with: ./run-tasks.sh --start $TASK_NUM"
    exit 1
  fi

  # ── Independent test verification ────────────────────────
  # Don't rely solely on aider's exit code — run tests independently
  # to catch failures aider may have given up on (reflection exhaustion
  # exits 0, not non-zero).
  if [[ -n "$TEST_CMD" ]]; then
    echo "   Verifying tests independently..."
    set +e
    VERIFY_OUTPUT=$(eval "$TEST_CMD" 2>&1)
    VERIFY_EXIT=$?
    set -e

    if [[ $VERIFY_EXIT -ne 0 ]]; then
      echo "   ⚠  Independent test verification failed (exit $VERIFY_EXIT)"
      echo "$VERIFY_OUTPUT" | tail -20
      echo "" >> "$LOG_FILE"
      echo "=== Independent test verification FAILED for $BASENAME ===" >> "$LOG_FILE"
      echo "$VERIFY_OUTPUT" >> "$LOG_FILE"

      if [[ "$REFLECTIONS_EXHAUSTED" == true ]]; then
        echo "   ⚠  Aider also exhausted reflections on this task."
        echo "   Marking as DEGRADED and continuing."
        DEGRADED=$((DEGRADED + 1))
        echo "⚠️  Degraded: $BASENAME (reflections exhausted, tests failing)"
        continue
      else
        echo ""
        echo "   Tests are failing but aider reported success."
        echo "   Fix the issue and re-run with: ./run-tasks.sh --start $TASK_NUM"
        exit 1
      fi
    fi
  fi

  # ── Reflection exhaustion without test failure ───────────
  # Tests pass but aider burned all reflections — likely a lint issue
  # it couldn't resolve. Log it but continue.
  if [[ "$REFLECTIONS_EXHAUSTED" == true ]]; then
    echo "⚠️  Completed with warnings: $BASENAME (reflections exhausted but tests pass)"
    DEGRADED=$((DEGRADED + 1))
  else
    echo "✅  Completed: $BASENAME"
  fi

  SUCCEEDED=$((SUCCEEDED + 1))
done

# ── Check for deferred tasks that don't have .md files yet ───
if [[ -n "$DEFERRED_TASKS" && "$DEFERRED_HIT" != true ]]; then
  MISSING_DEFERRED=""
  while IFS= read -r deferred_file; do
    [[ -z "$deferred_file" ]] && continue
    if [[ ! -f "$TASKS_DIR/$deferred_file" ]]; then
      MISSING_DEFERRED="$MISSING_DEFERRED  $deferred_file\n"
    fi
  done <<< "$DEFERRED_TASKS"

  if [[ -n "$MISSING_DEFERRED" ]]; then
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Implementation phase complete: $SUCCEEDED tasks succeeded, $DEGRADED degraded"
    echo ""
    echo "  Deferred task docs not yet generated:"
    echo -e "$MISSING_DEFERRED"
    echo "  Generate them with Claude Code (read actual source files),"
    echo "  then re-run to execute them."
    echo "═══════════════════════════════════════════════"
    exit 0
  fi
fi

echo ""
echo "═══════════════════════════════════════════════"
if [[ $DEGRADED -gt 0 ]]; then
  echo "  $SUCCEEDED tasks completed ($DEGRADED degraded — review these manually)"
else
  echo "  All $SUCCEEDED tasks completed successfully!"
fi
echo "═══════════════════════════════════════════════"
