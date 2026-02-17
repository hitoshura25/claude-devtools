---
name: agent-ready-plans
description: Use when you have a design document and implementation plan and need to break them into individual task files for smaller AI coding agents like aider with local models (Qwen Coder, Codestral). Also use when someone says "decompose this plan", "break this into aider tasks", "create task files for local agents", or wants to delegate implementation to smaller models running via LMStudio.
---

# Agent-Ready Plans

## Overview

Take a design document + implementation plan and decompose them into individual, self-contained task documents that smaller AI coding agents can execute sequentially. Each task doc is structured as an aider `--message-file` with everything a small model needs: context, instructions, code, lint/test commands, and verification criteria.

The key insight: large models (Claude) are great at architecture and planning, but the actual code generation can often be delegated to smaller, cheaper, local models. This skill bridges that gap by translating rich implementation plans into task files that don't require deep architectural understanding — just the ability to follow precise instructions and write code.

**Announce at start:** "I'm using the agent-ready-plans skill to break this plan into individual task files."

## When to Use

- You have a design doc and implementation plan
- You want to delegate implementation to aider + local models (Qwen Coder, Codestral via LMStudio)
- The plan has discrete tasks that can be executed sequentially
- You want to optimize cost by using Claude for planning and local models for coding

## When NOT to Use

- Plan requires complex cross-cutting architectural decisions mid-implementation
- Tasks are deeply interdependent and need holistic reasoning across the full codebase
- The implementation plan hasn't been written yet

## Input Requirements

1. **Design document** — the "what and why" (architecture, data model, decisions)
2. **Implementation plan** — the "how" (phased tasks with TDD steps, file paths, code)

Both are typically markdown files in `docs/plans/`.

## Output Structure

Create a subfolder next to the plan file, named after the plan (stripping the date prefix and `-implementation` suffix if present).

Example: if the plan is `docs/plans/2026-01-29-airflow-google-drive-ingestion-implementation.md`, create:

```
docs/plans/airflow-google-drive-ingestion-tasks/
├── 00-manifest.json              # Task index with metadata
├── 01-task-1.1-create-service-directory.md
├── 02-task-1.2-create-requirements-file.md
├── 03-task-1.3-create-pydantic-settings.md
├── ...
├── 25-task-12.1-dag-integration-test.md
└── run-tasks.sh                  # Sequential runner script
```

**Never use a generic `tasks/` directory.** Each plan gets its own uniquely-named output folder so multiple decompositions don't collide.

## Execution Strategy

**Do NOT use subagents or parallel Task agents to generate task files.** Subagents have restricted permissions and frequently fail to write files, causing partial output that requires manual recovery.

Generate all task files sequentially in the main session. Write each file to disk immediately before moving to the next. Show progress as files are created:
```
Creating 01-task-1.1-create-service-directory.md... ✓
Creating 02-task-1.2-create-requirements-file.md... ✓
...
```

## The Process

### Step 1: Read and Analyze the Plan

Read both the design doc and implementation plan. Build a mental model of:
- Total number of tasks
- Dependencies between phases
- Which tasks have full code vs. stubs/placeholders
- Test commands and lint configuration
- Project language and tooling (pytest, cargo test, npm test, etc.)

### Step 2: Extract Project Context

Before generating task files, extract a shared context block from the design doc. This gets embedded at the top of every task file so the small model understands the project without needing the full design doc.

The context block should be **brief** (10-15 lines max) — small models have limited context windows. Include only:
- What the project does (1-2 sentences)
- Tech stack
- Key directory structure
- Naming conventions or patterns the model needs to follow

### Step 3: Generate Task Documents

For each task in the implementation plan, generate a standalone markdown file following the template in `task-template.md`.

**Naming convention:** `NN-task-X.Y-short-description.md`
- `NN` = zero-padded sequential number (execution order)
- `X.Y` = original task number from the plan
- `short-description` = kebab-case summary

**Critical rules for task docs:**

1. **Self-contained** — each task doc has everything the agent needs. No references to "see the design doc" or "as described in Phase 2". Inline the relevant context.

2. **Explicit file paths** — always absolute from project root. Never relative, never ambiguous.

3. **Complete code** — include the full code to write, not "add validation logic here". Small models need the actual implementation, not instructions to figure it out.

4. **One commit per task** — each task ends with a specific `git add` + `git commit` with a conventional commit message.

5. **Test-first ordering** — when a task has TDD steps, the test file content comes before the implementation file content in the instructions.

6. **Verification section** — every task ends with a checklist of files that should exist and test commands that should pass.

### Step 4: Generate the Manifest

Create `00-manifest.json` with task metadata:

```json
{
  "plan_source": "docs/plans/2026-01-29-airflow-google-drive-ingestion-implementation.md",
  "design_source": "docs/plans/2026-01-29-airflow-google-drive-ingestion-design.md",
  "generated_at": "2026-01-29T18:00:00Z",
  "total_tasks": 25,
  "tasks": [
    {
      "file": "01-task-1.1-create-service-directory.md",
      "task_id": "1.1",
      "title": "Create Service Directory Structure",
      "phase": "Project Scaffolding",
      "files_created": ["services/airflow-ingestion/dags/.gitkeep", "..."],
      "files_modified": [],
      "test_command": null,
      "estimated_complexity": "simple"
    }
  ]
}
```

### Step 5: Generate the Runner Script

Create `run-tasks.sh` — a bash script that executes each task via aider sequentially.

```bash
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
DEFAULT_MODEL="lm_studio/qwen/qwen3-coder-30b"
LINT_CMD=""        # Set if project has a linter, e.g. "ruff check ."
TEST_CMD=""        # Set if project has a test runner, e.g. "pytest"

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

echo "╔══════════════════════════════════════════════╗"
echo "║  Task Runner — $TOTAL tasks queued              ║"
echo "║  Model: $MODEL"
echo "║  Starting from task: $START_TASK               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

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

  # Add lint command if configured
  if [[ -n "$LINT_CMD" ]]; then
    AIDER_ARGS+=(--lint-cmd "$LINT_CMD")
  fi

  # Add test command if configured
  if [[ -n "$TEST_CMD" ]]; then
    AIDER_ARGS+=(--test-cmd "$TEST_CMD")
  fi

  aider "${AIDER_ARGS[@]}"

  AIDER_EXIT=$?
  if [[ $AIDER_EXIT -ne 0 ]]; then
    echo ""
    echo "⚠  aider exited with code $AIDER_EXIT on $BASENAME"
    echo "   Fix the issue and re-run with: ./run-tasks.sh --start $TASK_NUM"
    exit 1
  fi

  echo "✅  Completed: $BASENAME"
done

echo ""
echo "═══════════════════════════════════════════════"
echo "  All $TOTAL tasks completed successfully!"
echo "═══════════════════════════════════════════════"
```

**Runner script rules:**
- `--start N` flag so you can resume after a failure
- `--dry-run` to preview without executing
- `--model` overridable for switching between local models
- `--lint-cmd` and `--test-cmd` for project-specific tooling
- `--no-git` — the task doc itself includes the git commit step, so aider shouldn't commit on its own
- Non-zero exit from aider halts the runner and tells you how to resume
- LMStudio defaults: `http://localhost:1234/v1` with `lm_studio/` model prefix

### Step 6: Present Results

After generating all files, present a summary:

```
Generated 25 task files + manifest + runner script in docs/plans/airflow-google-drive-ingestion-tasks/

Phase breakdown:
  Phase 1: Project Scaffolding    — 3 tasks (simple)
  Phase 2: Google Drive Client    — 1 task (moderate)
  Phase 3: SQLite Parser          — 1 task (moderate)
  ...

To run:
  cd docs/plans/airflow-google-drive-ingestion-tasks
  chmod +x run-tasks.sh
  ./run-tasks.sh --dry-run          # Preview
  ./run-tasks.sh                    # Execute all
  ./run-tasks.sh --start 5          # Resume from task 5
```

## Writing Effective Task Docs for Small Models

Small models (7B-32B) need different instruction style than Claude:

1. **Be explicit, not clever** — spell out every step. Don't say "follow the same pattern as the steps extractor". Copy the pattern inline.

2. **One thing at a time** — each instruction should do exactly one thing. "Create file X with this content" not "Create the test file, run it, then create the implementation".

3. **Full code always** — never say "implement the transform method". Provide the complete method body. Small models struggle with underspecified implementations.

4. **Minimize context requirements** — the model shouldn't need to read other files to understand what to do. If it needs to know an interface, include the interface definition in the task doc.

5. **Concrete over abstract** — "Create a class `StepsExtractor` that inherits from `BaseRecordExtractor`" with the full class body is better than "Create an extractor following the base class pattern".

6. **Keep task docs under 2000 tokens** — small model context windows are limited. If a task would exceed this, split it into sub-tasks.

## Adapting the Runner for Different Agents

The runner script defaults to aider + LMStudio, but the task docs themselves are agent-agnostic markdown. You can also use them with:

- **Claude Code** — `cat task-file.md | claude-code` or paste into a session
- **Codex CLI** — use as input prompt
- **Any agent with a message-file param** — the format is universal

To add a new agent backend, the main things to change in the runner are the command and its arguments.

## Reference

See `task-template.md` for the complete task document template with all sections.
