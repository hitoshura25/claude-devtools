---
name: implementation-planning
description: Design features and produce implementation plans optimized for agent-ready task decomposition. Use this skill whenever someone says "plan this feature", "design and plan", "I need an implementation plan", "help me plan", or has a feature idea that needs to go from concept to actionable tasks. Also trigger when someone mentions wanting to use local models, aider, or task decomposition — even if they don't explicitly ask for a "plan". This skill produces the design doc and implementation plan; use devtools:agent-ready-plans afterward to decompose it into task files.
---

# Implementation Planning

Turn a feature idea into a design document and implementation plan that decomposes cleanly into agent-ready task files. The plan defines interface contracts and behavioral specs for each component — precise enough for Claude Code to write verified tests, and for a small model to implement the code that passes them.

This skill produces two artifacts:
1. **Design document** — the what and why (architecture, data model, decisions)
2. **Implementation plan** — the how (phased tasks with interface contracts, behavior specs, test scenarios, and wiring steps)

These feed directly into `devtools:agent-ready-plans` for task decomposition.

Announce at start: "I'm using the implementation-planning skill to design and plan this feature."

## Process

### 1. Explore the Idea

Use `superpowers:brainstorming` for the design exploration phase — understanding project context, asking focused questions, proposing approaches with trade-offs, and reaching a shared understanding of what's being built.

**Scope boundary:** Use brainstorming *only* through its design document output. Once the design doc is saved to `docs/plans/YYYY-MM-DD-<feature-name>-design.md`, stop the brainstorming workflow and return here to Step 2. Do not follow the brainstorming skill's "After the Design" section — it chains into `superpowers:writing-plans` which produces a generic plan format. This skill replaces that step with a plan format optimized for agent-ready task decomposition. Also skip any git commit steps from brainstorming — do not commit, stage, or add files unless the user explicitly asks.

If the user already has a design document (or provides enough context to skip brainstorming), move directly to Step 2.

### 2. Write the Implementation Plan

This is where precision matters most. The plan is the source of truth that the agent-ready-plans skill decomposes into individual task files for small models.

**The plan defines interfaces, not implementations.** Each task specifies: what class/function to create, its public method signatures with type hints, behavioral requirements, test scenarios, and how it wires into the rest of the system. Claude Code uses these specs to write and validate the tests; the small model writes the implementation to make them pass.

Read `references/plan-format.md` for the complete plan structure, task template, and formatting.

**Key principles for plans that decompose well:**

**Precise interface contracts.** Every task must define the class name, method signatures, parameter types, and return types that downstream tasks depend on. The model can structure its internals however it wants, but the public interface must match the spec so cross-task imports work.

**Concrete behavioral specs.** Don't say "handles edge cases" — say "returns empty list when no records are newer than the watermark." Each behavior becomes a test scenario the model implements. The more specific the scenario, the more meaningful the tests.

**Test scenarios for Claude Code, not test code.** Describe what to set up and what to assert: "In-memory SQLite with 3 rows at times 1000/2000/3000, extract with watermark=1500 → returns only rows at 2000 and 3000." Claude Code uses these scenarios to write and validate the actual test code during the agent-ready-plans scaffold phase. See "Writing Test Scenarios" in `references/plan-format.md`.

**Environment constraints, not mock instructions.** When a project has unusual testing requirements (Airflow not installed, RabbitMQ not running), state these as constraints: "Mock pika.BlockingConnection — no real connections in tests." Don't prescribe the exact mock pattern — the model picks one that works with its implementation.

**Complete wiring.** Every component that gets created must also be wired into whatever consumes it — in the same task or an explicit later task. Read `references/wiring-completeness.md` for the detailed checklist.

**Exact file paths.** Always specify the full path from project root. Never "create a config file" — always "create `services/airflow-ingestion/config/settings.py`".

**Scaffold as a separate concern.** Phase 1 (project scaffold) is not a task for the small model. List what the scaffold contains in the plan — the agent-ready-plans skill creates these files directly via Claude Code before delegating tasks to the small model.

**Flag deferred tasks.** Integration tests that depend on exact interfaces from multiple tasks should be marked as deferred. Their precise signatures can only be known after the implementation tasks have run.

Save to `docs/plans/YYYY-MM-DD-<feature-name>-implementation.md`.

**No automatic git operations.** Do not commit, stage, or add files to git unless the user explicitly asks. Planning artifacts are the user's to manage.

### 3. Validate the Plan

Before handing off, walk through the wiring completeness checklist in `references/wiring-completeness.md`:

- Every file created in the plan is consumed, imported, or registered somewhere
- Every registry, factory, router, or dispatcher gets updated when new entries are added in later phases
- Cross-phase dependencies are explicit (not implied by task ordering)
- Integration tests are flagged as deferred
- Every task's interface contract includes type hints on all public methods
- Every task's test scenarios are specific enough to verify the behavioral specs

If gaps are found, update the plan. This check is worth the 5 minutes — a single missing registration step causes cascading test failures across 20 automated tasks.

### 4. Hand Off

Present the completed artifacts and offer the choice:

```
Design: docs/plans/YYYY-MM-DD-feature-name-design.md
Plan:   docs/plans/YYYY-MM-DD-feature-name-implementation.md

Phase breakdown:
  Phase 1: Project Scaffolding    — Claude Code creates directly
  Phase 2: Core Components        — 4 tasks (spec-based)
  ...
  Phase N: Integration Tests      — 2 tasks (deferred)

Ready to decompose into agent-ready task files now, or would you
prefer to review the plan first and decompose later?
```

If the user wants to proceed immediately, use `devtools:agent-ready-plans` with the design doc and implementation plan as inputs. If they want to review first, point them to the files and remind them they can trigger decomposition later with `/devtools:agent-ready`.

## What This Skill Does NOT Do

- Does not implement any code (except scaffold files via agent-ready-plans)
- Does not create task files (that's agent-ready-plans)
- Does not run tests or modify source files
- Does not touch anything outside of `docs/plans/`
- Does not commit, stage, or add files to git

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `references/plan-format.md` | When writing the implementation plan (Step 2) — complete structure, task template, formatting |
| `references/wiring-completeness.md` | When writing cross-phase tasks (Step 2) and validating the plan (Step 3) — checklist for registration gaps |
