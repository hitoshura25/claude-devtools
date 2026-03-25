#!/usr/bin/env bash
# validate-stubs.sh — Layer 2 validation gate
#
# Runs each test file individually against its stub and verifies that every
# test failure is caused by NotImplementedError or AssertionError — the only
# acceptable failure modes against stubs.
#
# Any other failure type (TypeError, FileNotFoundError, ImportError, etc.)
# indicates a bug in the test or stub that will break the implementing model.
#
# Output is written to a log file AND printed to the console. The planning
# model should reference the log file for full error details rather than
# piping this script through `| tail` or `| head`.
#
# Usage:
#   ./validate-stubs.sh <service-root> [test-dir]
#
# Examples:
#   ./validate-stubs.sh services/airflow-ingestion
#   ./validate-stubs.sh services/airflow-ingestion tests/test_extractors
#
# The script discovers all test_*.py files under <test-dir> (default: tests/)
# and runs each one individually. It parses pytest's --tb=line output to
# extract the error type from each FAILED line.
#
# Exit codes:
#   0 — All tests fail for acceptable reasons (NotImplementedError/AssertionError)
#       or pass (settings tests may pass against stubs if defaults satisfy assertions)
#   1 — At least one test fails for an unacceptable reason
#   2 — Script usage error or missing dependencies
#
# Log file: Written to <service-root>/validate-stubs-<timestamp>.log

set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <service-root> [test-dir]"
  echo "  service-root: Path to the service directory (e.g., services/airflow-ingestion)"
  echo "  test-dir:     Subdirectory to scan for tests (default: tests/)"
  exit 2
fi

SERVICE_ROOT="$1"
TEST_DIR="${2:-tests}"
FULL_TEST_DIR="$SERVICE_ROOT/$TEST_DIR"

if [[ ! -d "$FULL_TEST_DIR" ]]; then
  echo "❌ Test directory not found: $FULL_TEST_DIR"
  exit 2
fi

# ── Log file setup ─────────────────────────────────────────────
# Log file is written inside the service root so it stays with the project,
# not in the shared skill scripts directory.
LOG_FILE="$SERVICE_ROOT/validate-stubs-$(date +%Y%m%d-%H%M%S).log"

# Tee all output to both console and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Log file: $LOG_FILE"
echo ""

# ── Prevent terminal truncation ────────────────────────────────
# pytest 9.x truncates FAILED summary lines based on terminal width.
# Setting COLUMNS=300 ensures error types are never cut off.
export COLUMNS=300

# ── Acceptable error types ─────────────────────────────────────
# NotImplementedError: stub method bodies raise this
# AssertionError: test assertions fail against stub return values
# These are the ONLY acceptable failure modes against stubs.
ACCEPTABLE_ERRORS="NotImplementedError|AssertionError"

# ── Discover test files ────────────────────────────────────────
TEST_FILES=$(find "$FULL_TEST_DIR" -name "test_*.py" -type f | sort)
TOTAL=$(echo "$TEST_FILES" | wc -l | tr -d ' ')

if [[ -z "$TEST_FILES" || "$TOTAL" -eq 0 ]]; then
  echo "❌ No test files found in $FULL_TEST_DIR"
  exit 2
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  Layer 2 Stub Validation — $TOTAL test files"
echo "║  Service: $SERVICE_ROOT"
echo "║  Log: $LOG_FILE"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Run each test file individually ────────────────────────────
TOTAL_TESTS=0
ACCEPTABLE_FAILURES=0
BAD_FAILURES=0
PASSES=0
BAD_FILES=()

for TEST_FILE in $TEST_FILES; do
  # Make path relative to service root for pytest
  REL_PATH="${TEST_FILE#$SERVICE_ROOT/}"
  BASENAME=$(basename "$TEST_FILE")

  echo "▶ $REL_PATH"

  # Run pytest with --tb=line for parseable failure output
  set +e
  OUTPUT=$(cd "$SERVICE_ROOT" && uv run pytest "$REL_PATH" --tb=line -q 2>&1)
  PYTEST_EXIT=$?
  set -e

  # Log full pytest output for this file
  echo "  --- pytest output for $REL_PATH ---" >> "$LOG_FILE"
  echo "$OUTPUT" >> "$LOG_FILE"
  echo "  --- end output ---" >> "$LOG_FILE"

  if [[ $PYTEST_EXIT -eq 0 ]]; then
    # All tests passed — acceptable (e.g., settings defaults)
    PASS_COUNT=$(echo "$OUTPUT" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo "0")
    PASSES=$((PASSES + PASS_COUNT))
    echo "  ✅ $PASS_COUNT passed"
    continue
  fi

  # Parse FAILED lines for error types
  FILE_BAD=0
  FILE_OK=0
  FILE_PASS=0

  # Count passes in this file
  FILE_PASS=$(echo "$OUTPUT" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo "0")
  PASSES=$((PASSES + FILE_PASS))

  while IFS= read -r line; do
    # Extract the error type from FAILED lines
    # Format: "FAILED tests/test_foo.py::test_bar - ErrorType: message"
    if echo "$line" | grep -qE "^FAILED "; then
      TOTAL_TESTS=$((TOTAL_TESTS + 1))

      # Extract error type after " - "
      ERROR_PART=$(echo "$line" | sed 's/.*- //')
      ERROR_TYPE=$(echo "$ERROR_PART" | grep -oE '^[A-Za-z_]+Error' || echo "")

      # If no error type found (pytest truncation or bare assertion),
      # check for known patterns
      if [[ -z "$ERROR_TYPE" ]]; then
        # "assert X == Y" without AssertionError prefix
        if echo "$ERROR_PART" | grep -qE "^assert "; then
          ERROR_TYPE="AssertionError"
        else
          ERROR_TYPE="UNKNOWN"
        fi
      fi

      # Also check for TypeError pattern "Can't instantiate abstract class"
      if echo "$ERROR_PART" | grep -q "Can't instantiate abstract class"; then
        ERROR_TYPE="TypeError"
      fi

      TEST_NAME=$(echo "$line" | sed 's/FAILED //' | sed 's/ - .*//')

      if echo "$ERROR_TYPE" | grep -qE "^($ACCEPTABLE_ERRORS)$"; then
        FILE_OK=$((FILE_OK + 1))
      else
        FILE_BAD=$((FILE_BAD + 1))
        echo "  ❌ $TEST_NAME"
        echo "     Failed with: $ERROR_TYPE (expected NotImplementedError or AssertionError)"
        echo "     $ERROR_PART"
      fi
    fi

    # Also catch ERROR lines (setup/fixture errors)
    if echo "$line" | grep -qE "^ERROR "; then
      TOTAL_TESTS=$((TOTAL_TESTS + 1))
      FILE_BAD=$((FILE_BAD + 1))
      ERROR_NAME=$(echo "$line" | sed 's/ERROR //' | sed 's/ - .*//')
      echo "  ❌ $ERROR_NAME"
      echo "     Setup/fixture error (not a stub failure)"
    fi
  done <<< "$OUTPUT"

  ACCEPTABLE_FAILURES=$((ACCEPTABLE_FAILURES + FILE_OK))
  BAD_FAILURES=$((BAD_FAILURES + FILE_BAD))

  if [[ $FILE_BAD -gt 0 ]]; then
    BAD_FILES+=("$REL_PATH")
    echo "  ⚠️  $FILE_BAD invalid failure(s), $FILE_OK acceptable"
  else
    echo "  ✅ $FILE_OK failures — all NotImplementedError/AssertionError"
  fi

  echo ""
done

# ── Summary ────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════"
echo "  Passed:              $PASSES"
echo "  Acceptable failures: $ACCEPTABLE_FAILURES"
echo "  Invalid failures:    $BAD_FAILURES"
echo "═══════════════════════════════════════════════"

if [[ $BAD_FAILURES -gt 0 ]]; then
  echo ""
  echo "❌ Layer 2 FAILED — $BAD_FAILURES test(s) fail for the wrong reason."
  echo ""
  echo "Files with invalid failures:"
  for f in "${BAD_FILES[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "Full output is in: $LOG_FILE"
  echo "Review the log file for complete tracebacks."
  echo ""
  echo "Fix these before proceeding. Each test must fail with"
  echo "NotImplementedError (stub body) or AssertionError (wrong return)."
  echo "Any other error type means the test or stub has a bug."
  exit 1
else
  echo ""
  echo "✅ Layer 2 PASSED — all failures are acceptable stub behavior."
  echo "Full log: $LOG_FILE"
  exit 0
fi
