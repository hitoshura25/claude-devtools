---
description: Delegate implementation task to local SERA model via Goose
---

# SERA Implementation

Delegate implementation tasks to local SERA-32B model, conserving Claude Pro usage.

## The Rule

**Always check setup BEFORE delegating.** Don't assume SERA is ready.

## Usage

```
/devtools:sera [task-number]
```

**Examples:**
```
/devtools:sera                    # Delegate current/next task
/devtools:sera 3                  # Delegate task 3 from plan
/devtools:sera 5.1                # Delegate task 5.1
/devtools:sera "Add user auth"    # Delegate by task name
```

## Process

### Step 1: Check Setup (REQUIRED)

```bash
# Check 1: Goose installed?
command -v goose

# Check 2: Provider configured?
test -f ~/.config/goose/custom_providers/sera_mlx.json

# Check 3: Server script exists?
test -f ~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh
```

**If any check fails: STOP AND ASK USER**

```
┌─────────────────────────────────────────────────────────────────┐
│  DO NOT DECIDE FOR THE USER. ASK AND WAIT FOR RESPONSE.        │
└─────────────────────────────────────────────────────────────────┘
```

**Say EXACTLY this:**

> SERA setup is not complete. This requires:
> - Installing mlx-lm and Goose
> - Downloading the SERA-32B model (18.4GB)
> - Configuring the Goose provider
>
> **Option 1:** I can run the setup script now (will take several minutes for model download)
> **Option 2:** I can implement this task directly using Claude instead
>
> Which would you prefer?

**Then STOP. Wait for user response before doing anything else.**

- User says "setup" / "option 1" → Run `~/claude-devtools/skills/implementing-with-sera/scripts/setup.sh`
- User says "implement" / "option 2" / "Claude" → Implement directly
- User says something unclear → Ask for clarification

**NEVER assume the user's choice. NEVER proceed without explicit response.**

### Step 2: Start Server If Needed

```bash
~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh status \
  || ~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh start
```

Wait for: "✅ SERA server started successfully"

### Step 3: Find Implementation Plan

```bash
ls docs/plans/*-implementation.md
```

### Step 4: Extract Task

From the plan, extract the specified task (or next incomplete task):
- Task name and number
- Full task specification
- Acceptance criteria
- Files to create/modify

### Step 5: Create Task Context

Create `/tmp/sera-task-context.md` with:

```markdown
# Task: [Task Name]

## Design Reference
See: docs/plans/YYYY-MM-DD-feature-design.md
Section: [Relevant section]

## Task Specification
[Exact task text from plan]

## Acceptance Criteria
1. [Criterion 1]
2. [Criterion 2]
3. All tests pass
4. No lint errors

## Files
- Create: path/to/new_file.py
- Test: tests/test_file.py

## Constraints
- Follow existing patterns in [directory]
```

### Step 6: Execute

```bash
~/claude-devtools/skills/implementing-with-sera/scripts/sera-run.sh /tmp/sera-task-context.md
```

### Step 7: Handle Result

**If successful:**
> Task [N] completed via SERA. Files created:
> - [list files]
>
> Tests: ✅ Passing
> Lint: ✅ Clean
> Committed: feat: [task name] (SERA)

**If SERA execution failed (Goose error, crash, config issue):**

```
┌─────────────────────────────────────────────────────────────────┐
│  SERA FAILED. DO NOT SILENTLY SWITCH TO CLAUDE.                 │
│  ASK THE USER WHAT THEY WANT TO DO.                            │
└─────────────────────────────────────────────────────────────────┘
```

**Say EXACTLY this:**

> SERA execution failed with error:
> ```
> [paste actual error message]
> ```
>
> **Option 1:** Debug and retry SERA (check server, config, logs)
> **Option 2:** I can implement this task directly using Claude instead
>
> Which would you prefer?

**Then STOP. Wait for user response.**

- User says "debug" / "retry" / "option 1" → Check logs, restart server, retry
- User says "implement" / "option 2" / "Claude" → Implement directly

**NEVER say "Let me implement directly" without asking first.**

## Server Management

```bash
# Stop server (free 24GB RAM)
~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh stop

# Check status
~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh status

# View logs
~/claude-devtools/skills/implementing-with-sera/scripts/sera-server.sh logs
```

## When NOT to Delegate

| Scenario | Action |
|----------|--------|
| Design decisions | Use Claude |
| Non-Python code | Use Claude |
| Complex refactoring | Use Claude |
| Security-critical | Use Claude |
| Context > 32K tokens | Chunk task or use Claude |
| 2+ SERA failures | Fall back to Claude |

## Red Flags

| Thought | Reality |
|---------|---------|
| "Skip setup check" | Setup check is REQUIRED |
| "Probably fine without asking" | ASK before running 18GB download |
| "One more SERA try" | 2 failures = fall back |
| **"Since SERA isn't set up, I'll just implement directly"** | **NO. ASK THE USER FIRST. Present options, wait for response.** |
| **"User probably wants me to..."** | **NO. Never assume. Always ask.** |
| **"SERA failed - let me implement directly"** | **NO. Show error, present options, WAIT for user response.** |
| **"Let me implement the tasks directly using Claude instead"** | **NO. This exact phrase is the rationalization to avoid.** |
