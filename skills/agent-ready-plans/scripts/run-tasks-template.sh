#!/usr/bin/env bash
# Auto-generated task runner for aider
# Usage: ./run-tasks.sh [--start N] [--dry-run] [--model MODEL]
#
# Prerequisites:
#   - aider installed (pip install aider-chat)
#   - LMStudio running with model loaded (for local models)
#   - Docker installed and daemon running (required for infrastructure tasks)
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
#
# NOTE — generation length cap:
#   Aider's --timeout flag only caps the HTTP *connection setup* phase.
#   It does NOT interrupt an in-progress streaming response. Once the model
#   starts generating (stream: true, which LM Studio uses by default), the
#   timeout never fires regardless of how long generation takes.
#
#   The reliable fix is a server-side generation cap in LM Studio:
#   Settings → "Max Tokens to Predict" — set to a value like 8192.
#   This hard-caps token output per request, preventing indefinite
#   summarizer or reflection spirals at the model level rather than the
#   HTTP level. Alternatively, configure aider with stream: false in
#   ~/.aider.conf.yml, which makes --timeout effective again.

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
export LM_STUDIO_API_KEY=dummy-api-key
export LM_STUDIO_API_BASE=http://localhost:1234/v1

TASKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TASKS_DIR/../../.." && pwd)"
MANIFEST="$TASKS_DIR/00-manifest.json"
LOG_FILE="$TASKS_DIR/run-$(date +%Y%m%d-%H%M%S).log"
DEFAULT_MODEL="lm_studio/qwen/qwen3-coder-30b"

# Read tooling config from manifest.
# GLOBAL_LINT_CMD and TEST_CMD are defaults used when a task doesn't specify
# its own lint_cmd or test_command. TEST_CMD is also used for the final
# full-suite check at the end of the run.
if [[ -f "$MANIFEST" ]]; then
  GLOBAL_LINT_CMD=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('tooling',{}).get('lint_cmd',''))" 2>/dev/null || echo "")
  TEST_CMD=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('tooling',{}).get('test_cmd',''))" 2>/dev/null || echo "")
else
  echo "⚠  No manifest found at $MANIFEST — lint/test auto-validation disabled"
  GLOBAL_LINT_CMD=""
  TEST_CMD=""
fi

# ── Parse Arguments ────────────────────────────────────────────
START_TASK=1
DRY_RUN=false
MODEL="${DEFAULT_MODEL}"
LINT_CMD="${GLOBAL_LINT_CMD}"

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

# ── Helper: check required services are reachable ─────────────
# Required services are a hard requirement — if any are unavailable the run
# exits immediately. There is no skip-and-continue for service dependencies:
# a run that skips required services cannot be considered a valid result.
check_required_services() {
  local basename="$1"

  SERVICES_JSON=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$basename'), None)
if task is None or not task.get('requires_services'):
    print('{}')
    sys.exit(0)
checks = task.get('service_check_commands', {})
print(json.dumps(checks))
" 2>/dev/null || echo "{}")

  if [[ "$SERVICES_JSON" == "{}" ]]; then
    return 0
  fi

  python3 -c "
import json, subprocess, sys
checks = json.loads('$SERVICES_JSON')
failed = []
for svc, cmd in checks.items():
    result = subprocess.run(cmd, shell=True, capture_output=True)
    if result.returncode != 0:
        failed.append(svc)
if failed:
    print('UNAVAILABLE: ' + ', '.join(failed))
    sys.exit(1)
" 2>/dev/null
  return $?
}

# ── Run Tasks ──────────────────────────────────────────────────
cd "$PROJECT_ROOT"

TASK_FILES=($(ls "$TASKS_DIR"/[0-9][0-9]-task-*.md 2>/dev/null | sort))
TOTAL=${#TASK_FILES[@]}
EXISTING_COUNT=${#TASK_FILES[@]}

if [[ $EXISTING_COUNT -eq 0 ]]; then
  echo "❌  No task files found in $TASKS_DIR"
  exit 1
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  Task Runner — $EXISTING_COUNT task files"
echo "║  Model: $MODEL"
echo "║  Starting from task: $START_TASK"
echo "║  Log: $LOG_FILE"
if [[ -n "$LINT_CMD" ]]; then
  echo "║  Default lint: $LINT_CMD"
fi
if [[ -n "$TEST_CMD" ]]; then
  echo "║  Final suite check: $TEST_CMD"
fi
echo "╚══════════════════════════════════════════════╝"
echo ""

SUCCEEDED=0
DEGRADED=0

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

  # ── Check required services — hard fail if unavailable ─────
  # Required services are not optional. If they're not running, the run stops
  # here so the developer can start them and resume with --start N.
  # This ensures every run produces a complete, valid result.
  REQUIRES_SERVICES=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$BASENAME'), None)
if task is None or not task.get('requires_services'):
    print('false')
else:
    print(','.join(task['requires_services']))
" 2>/dev/null || echo "false")

  if [[ "$REQUIRES_SERVICES" != "false" ]]; then
    SERVICE_CHECK_OUTPUT=$(python3 -c "
import json, subprocess
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$BASENAME'), None)
checks = task.get('service_check_commands', {})
failed = []
for svc, cmd in checks.items():
    result = subprocess.run(cmd, shell=True, capture_output=True)
    if result.returncode != 0:
        failed.append(svc)
if failed:
    print('UNAVAILABLE: ' + ', '.join(failed))
else:
    print('OK')
" 2>/dev/null || echo "CHECK_ERROR")

    if [[ "$SERVICE_CHECK_OUTPUT" != "OK" ]]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "❌  Required services unavailable: $BASENAME"
      echo "   Requires: $REQUIRES_SERVICES"
      echo "   Status:   $SERVICE_CHECK_OUTPUT"
      echo ""
      echo "   Start the required services, then resume with:"
      echo "   ./run-tasks.sh --start $TASK_NUM"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 1
    fi
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "▶  Running: $BASENAME ($TASK_NUM/$TOTAL)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$DRY_RUN" == true ]]; then
    echo "   [DRY RUN] Would execute aider with $BASENAME"
    continue
  fi

  # ── Per-task lint command ──────────────────────────────────
  # Infrastructure tasks (Dockerfile, compose) use a different linter than
  # Python tasks. If the manifest specifies a lint_cmd for this task, use it;
  # otherwise fall back to the global lint command from the tooling block.
  TASK_LINT_CMD=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$BASENAME'), None)
if task is None:
    print('')
else:
    print(task.get('lint_cmd', '') or '')
" 2>/dev/null || echo "")

  # Use task-level lint_cmd if set, otherwise fall back to global
  EFFECTIVE_LINT_CMD="${TASK_LINT_CMD:-$LINT_CMD}"
  if [[ -z "$EFFECTIVE_LINT_CMD" && -n "$LINT_CMD" ]]; then
    EFFECTIVE_LINT_CMD="$LINT_CMD"
  fi

  # ── Per-task test command ──────────────────────────────────
  # Each task has its own test_command scoped to its own test or smoke test.
  # This prevents aider from running the global suite during a task's retry
  # loop — which would cascade-fail if earlier tasks have failing tests.
  #
  # If test_command is absent or null in the manifest, this task has no test
  # gate. The runner does NOT fall back to the global suite — the global suite
  # is only for the final full-stack check at the end of the run.
  TASK_TEST_CMD=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
task = next((t for t in m.get('tasks', []) if t.get('file') == '$BASENAME'), None)
if task is None:
    print('')
else:
    # Treat both null and empty string as 'no test command'
    cmd = task.get('test_command')
    print(cmd if cmd else '')
" 2>/dev/null || echo "")

  # ── Build aider arguments ─────────────────────────────────
  AIDER_ARGS=(
    --model "$MODEL"
    --no-show-model-warnings
    --no-check-update
    --no-git
    --message-file "$TASK_FILE"
    --yes-always
  )

  # Lint: aider appends edited filenames to lint_cmd, so it must work from
  # project root. Do NOT use 'cd' in lint_cmd.
  if [[ -n "$EFFECTIVE_LINT_CMD" ]]; then
    AIDER_ARGS+=(--lint-cmd "$EFFECTIVE_LINT_CMD" --auto-lint)
    if [[ -n "$TASK_LINT_CMD" && "$TASK_LINT_CMD" != "$LINT_CMD" ]]; then
      echo "   Using per-task lint: $TASK_LINT_CMD"
    fi
  fi

  # Test: use per-task test_command if set.
  # No fallback to global — missing test_command means lint-only for this task.
  if [[ -n "$TASK_TEST_CMD" ]]; then
    AIDER_ARGS+=(--test-cmd "$TASK_TEST_CMD" --auto-test)
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
  # Run tests independently to catch failures aider may have given up on
  # (reflection exhaustion exits 0, not non-zero).
  # Only run if this task has a test command — no global fallback.
  if [[ -n "$TASK_TEST_CMD" ]]; then
    echo "   Verifying tests independently..."
    set +e
    VERIFY_OUTPUT=$(eval "$TASK_TEST_CMD" 2>&1)
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

# ── Final full-suite check ────────────────────────────────────
# Now that all tasks are done, run the global test suite once as a sanity
# check that nothing broke across task boundaries. This runs the service's
# unit tests only (not integration tests, which have their own task).
if [[ -n "$TEST_CMD" && "$DRY_RUN" != true ]]; then
  echo ""
  echo "Running final full-suite check..."
  set +e
  FINAL_OUTPUT=$(eval "$TEST_CMD" 2>&1)
  FINAL_EXIT=$?
  set -e
  if [[ $FINAL_EXIT -ne 0 ]]; then
    echo "⚠️  Full suite check failed — some cross-task integration may be broken."
    echo "$FINAL_OUTPUT" | tail -20
    echo "" >> "$LOG_FILE"
    echo "=== Final full-suite check FAILED ===" >> "$LOG_FILE"
    echo "$FINAL_OUTPUT" >> "$LOG_FILE"
  else
    echo "✅  Full suite passed."
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
