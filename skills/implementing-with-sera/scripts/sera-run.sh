#!/bin/bash
# SERA Implementation Runner
# Handles: server check, goose execution, verification
# Usage: sera-run.sh <task-context.md> [--no-commit]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
GOOSEHINTS="${SKILL_DIR}/goosehints/sera-implementation.md"

# Model configuration
MODEL="hitoshura25/SERA-32B-mlx-4Bit"
PROVIDER="sera_mlx"

TASK_FILE="$1"
NO_COMMIT="${2:-}"

if [[ -z "$TASK_FILE" ]]; then
    echo "Usage: sera-run.sh <task-context.md> [--no-commit]"
    echo ""
    echo "Options:"
    echo "  --no-commit    Skip automatic commit on success"
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    echo "❌ Task file not found: $TASK_FILE"
    exit 1
fi

echo "=== SERA Implementation Runner ==="
echo "Task: $TASK_FILE"
echo "Provider: $PROVIDER"
echo "Model: $MODEL"
echo ""

# Step 0: Check provider exists
PROVIDER_FILE="${HOME}/.config/goose/custom_providers/${PROVIDER}.json"
if [[ ! -f "$PROVIDER_FILE" ]]; then
    echo "❌ SERA provider not found: $PROVIDER_FILE"
    echo "Run setup.sh first to create the provider"
    exit 1
fi

# Step 1: Ensure server is running
echo "[1/4] Checking SERA server..."
if ! "${SCRIPT_DIR}/sera-server.sh" status &>/dev/null; then
    echo "Starting server..."
    "${SCRIPT_DIR}/sera-server.sh" start
fi
echo ""

# Step 2: Ensure SERA_API_KEY is set
export SERA_API_KEY="${SERA_API_KEY:-local}"

# Step 3: Run Goose with profile and task file
echo "[2/4] Running SERA via Goose..."
echo ""

# Combine goosehints with task file into a single prompt
TEMP_PROMPT=$(mktemp)
cat > "$TEMP_PROMPT" << EOF
# Instructions

$(cat "$GOOSEHINTS")

# Task

$(cat "$TASK_FILE")
EOF

# Run goose with explicit provider, model, and developer extension
# Note: --profile doesn't exist in goose CLI, use explicit flags instead
goose run \
    --provider "$PROVIDER" \
    --model "$MODEL" \
    --with-builtin "developer" \
    -i "$TEMP_PROMPT"
GOOSE_EXIT=$?

rm -f "$TEMP_PROMPT"

if [[ $GOOSE_EXIT -ne 0 ]]; then
    echo ""
    echo "❌ Goose execution failed"
    exit 1
fi

echo ""
echo "[3/4] Verifying implementation..."

# Step 4: Run verification (tests + lint)
VERIFY_FAILED=0

# Detect test framework and run
if [[ -f "pyproject.toml" ]] || [[ -f "pytest.ini" ]] || [[ -d "tests" ]]; then
    echo "Running pytest..."
    if ! pytest --tb=short -q; then
        echo "❌ Tests failed"
        VERIFY_FAILED=1
    else
        echo "✅ Tests passed"
    fi
fi

# Run ruff if available
if command -v ruff &>/dev/null; then
    echo "Running ruff..."
    if ! ruff check .; then
        echo "❌ Lint errors found"
        VERIFY_FAILED=1
    else
        echo "✅ Lint passed"
    fi
fi

if [[ $VERIFY_FAILED -ne 0 ]]; then
    echo ""
    echo "❌ Verification failed - review and fix issues"
    echo "Re-run with: sera-run.sh $TASK_FILE"
    exit 1
fi

echo ""
echo "[4/4] Finalizing..."

# Step 5: Commit if requested
if [[ "$NO_COMMIT" != "--no-commit" ]]; then
    if [[ -n $(git status --porcelain) ]]; then
        # Extract task name from file for commit message
        TASK_NAME=$(head -1 "$TASK_FILE" | sed 's/^#* *//' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        TASK_NAME=${TASK_NAME:-sera-implementation}

        echo "Committing changes..."
        git add -A
        git commit -m "feat: ${TASK_NAME} (SERA)"
        echo "✅ Changes committed"
    else
        echo "No changes to commit"
    fi
else
    echo "Skipping commit (--no-commit)"
fi

echo ""
echo "=== ✅ Implementation Complete ==="
