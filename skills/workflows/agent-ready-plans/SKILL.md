---
name: agent-ready-plans
description: Use when decomposing an implementation plan into standalone task files for local coding agents
---

# Agent-Ready Plans

Break an implementation plan into standalone task files that local coding agents (Aider, Cline) can execute with zero additional context.

**Core principle:** Each task file is a complete, pre-approved instruction. The agent executes immediately — no permission, no narration, no describing what it would do.

**Announce at start:** "I'm using the agent-ready-plans skill to decompose this plan into task files."

**Save to:** `docs/plans/YYYY-MM-DD-feature-name/`

## The Process
Follow the below steps exactly in order. Do not skip, reorder, or add steps.

### Step 1: Read Plan

Read the implementation plan. Identify all tasks, dependencies, shared context.

### Step 2: Create `00-context.md`

Shared project context. Keep under 100 lines. Include: goal, tech stack, architecture, conventions, key files, test/lint commands.

### Step 3: Create Task Files

**For each task, you must exactly do the following.**
- For tasks that create implementation + test files: write the task file using the following template: `./task-template.md`
- For scaffolding-only tasks (just `__init__.py`, `.gitkeep`): write the task file using the following template `./scaffolding-template.md`
- Both templates start with an agent directive block. This block MUST appear in every generated task file. If a generated file is missing this block, it is broken.

### Step 4: Create README

Task table with dependency graph. Default execution command:

```bash
aider --model lm_studio/<model-name> \
      --no-git --yes --no-show-model-warnings \
      --read docs/plans/YYYY-MM-DD-feature-name/00-context.md \
      --message-file docs/plans/YYYY-MM-DD-feature-name/task-01-name.md
```

### Step 5: Self-Check

Verify every task file starts with the directive. Fix any that don't.

```bash
for f in docs/plans/*/task-*.md; do head -5 "$f"; echo "---"; done
```

## Remember

- Read the template file before creating each task file
- Directive block on every task file — no exceptions
- Use `## Files to Create` heading (not `## Steps`, `## What To Do`, `## Implementation`)
- Complete code inline — never say "see file X"
- No empty code blocks — use comments for placeholder files
- No `git add` / `git commit` in task files
- One concern per task, exact paths always

## Red Flags — STOP and Fix

- Task file missing directive block at top
- Task uses `## Steps` or `## What To Do` instead of `## Files to Create`
- Empty code block (`` ```python\n``` ``) — model will write literal backticks
- Task says "follow the pattern in X" instead of pasting the code
- Task includes git commit instructions
