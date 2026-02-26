---
name: implementation-planning
description: Design features and produce implementation plans optimized for agent-ready task decomposition. Use this skill whenever someone says "plan this feature", "design and plan", "I need an implementation plan", "help me plan", or has a feature idea that needs to go from concept to actionable tasks. Also trigger when someone mentions wanting to use local models, aider, or task decomposition — even if they don't explicitly ask for a "plan". This skill produces the design doc and implementation plan; use devtools:agent-ready-plans afterward to decompose it into task files.
---

# Implementation Planning

Turn a feature idea into a design document and implementation plan that decomposes cleanly into agent-ready task files. The plan is the bridge between "what we want to build" and "what a small model can execute" — it needs to be precise enough that every task becomes self-contained, with no implicit wiring or registration steps left to chance.

This skill produces two artifacts:
1. **Design document** — the what and why (architecture, data model, decisions)
2. **Implementation plan** — the how (phased tasks with TDD steps, file paths, complete code)

These feed directly into `devtools:agent-ready-plans` for task decomposition.

Announce at start: "I'm using the implementation-planning skill to design and plan this feature."

## Process

### 1. Explore the Idea

Use `superpowers:brainstorming` for the design exploration phase — understanding project context, asking focused questions, proposing approaches with trade-offs, and reaching a shared understanding of what's being built.

**Scope boundary:** Use brainstorming *only* through its design document output. Once the design doc is saved to `docs/plans/YYYY-MM-DD-<feature-name>-design.md`, stop the brainstorming workflow and return here to Step 2. Do not follow the brainstorming skill's "After the Design" section — it chains into `superpowers:writing-plans` which produces a generic plan format. This skill replaces that step with a plan format optimized for agent-ready task decomposition. Also skip any git commit steps from brainstorming — do not commit, stage, or add files unless the user explicitly asks.

If the user already has a design document (or provides enough context to skip brainstorming), move directly to Step 2.

### 2. Write the Implementation Plan

This is where precision matters most. The plan is the source of truth that the agent-ready-plans skill will decompose into individual task files for small models. Every gap or ambiguity in the plan becomes a bug in the task docs — small models follow instructions literally and can't fill in what's missing.

Read `references/plan-format.md` for the complete plan structure, task template, and formatting.

**Key principles for plans that decompose well:**

**Complete wiring.** Every component that gets created must also be wired into whatever consumes it — in the same task or an explicit later task. If task 8 creates a new extractor class and the DAG in task 5 has a registry of extractors, the plan must include a step to add the new extractor to that registry. Don't assume a small model will infer this. Read `references/wiring-completeness.md` for the detailed checklist and common patterns where registration gaps occur.

**Exact file paths.** Always specify the full path from project root. Never "create a config file" — always "create `services/airflow-ingestion/config/settings.py`".

**Complete code.** Provide the actual implementation, not "add validation logic here." The plan's code ends up verbatim in task docs that small models execute. Placeholders become bugs.

**TDD ordering.** For each task: write the failing test, then write the implementation that makes it pass. This gives the small model a concrete success signal at each step.

**Test business logic, not library functions.** Tests should verify that your code transforms fixture data correctly — not that Python's datetime or json modules work. When a test hardcodes a manually computed expected value (like an epoch-to-ISO conversion), it's easy to get wrong and impossible for the small model to diagnose. Use fixture data as the source of truth instead. See the "Writing Effective Tests" section in `references/plan-format.md`.

**One component per task.** Each task should create or modify a focused set of files with a single responsibility. If a task touches 5+ unrelated files, it probably needs splitting.

**Cross-phase awareness.** When a later phase adds components that plug into an earlier phase's output (new handlers for a router, new extractors for a pipeline, new commands for a dispatcher), the plan must include the registration step explicitly. This is the most common source of decomposition bugs — see `references/wiring-completeness.md`.

**Flag deferred tasks.** Integration tests and end-to-end tests that depend on the exact interfaces produced by multiple earlier tasks should be marked as deferred in the plan. Their precise signatures, mocks, and assertions can only be written accurately after the implementation tasks have run and the real code exists. Note these in the plan as "deferred — generate after implementation tasks complete."

Save to `docs/plans/YYYY-MM-DD-<feature-name>-implementation.md`.

**Writing strategy for large plans:** Plans with complete code for 15+ tasks will exceed tool output token limits if written in a single call. Write the plan incrementally — start with the header and first phase only, then append remaining phases one at a time using edit/append operations. Each chunk should cover a complete phase (don't split a task across chunks). If even a single phase is too large, write one task at a time within it.

**No automatic git operations.** Do not commit, stage, or add files to git unless the user explicitly asks. Planning artifacts are the user's to manage.

### 3. Validate the Plan

Before handing off, walk through the wiring completeness checklist in `references/wiring-completeness.md`:

- Every file created in the plan is consumed, imported, or registered somewhere
- Every registry, factory, router, or dispatcher gets updated when new entries are added in later phases
- Cross-phase dependencies are explicit (not implied by task ordering)
- Integration tests are flagged as deferred

If gaps are found, update the plan. This check is worth the 5 minutes — a single missing registration step causes cascading test failures across 25 automated tasks.

### 4. Hand Off

Present the completed artifacts and offer the choice:

```
Design: docs/plans/YYYY-MM-DD-feature-name-design.md
Plan:   docs/plans/YYYY-MM-DD-feature-name-implementation.md

Phase breakdown:
  Phase 1: Project Scaffolding    — 3 tasks
  Phase 2: Core Components        — 4 tasks
  ...
  Phase N: Integration Tests      — 2 tasks (deferred)

Ready to decompose into agent-ready task files now, or would you
prefer to review the plan first and decompose later?
```

If the user wants to proceed immediately, use `devtools:agent-ready-plans` with the design doc and implementation plan as inputs. If they want to review first, point them to the files and remind them they can trigger decomposition later with `/devtools:agent-ready`.

## What This Skill Does NOT Do

- Does not implement any code
- Does not create task files (that's agent-ready-plans)
- Does not run tests or modify source files
- Does not touch anything outside of `docs/plans/`

## Bundled Resources

| Resource | When to read |
|----------|-------------|
| `references/plan-format.md` | When writing the implementation plan (Step 2) — complete structure, task template, formatting |
| `references/wiring-completeness.md` | When writing cross-phase tasks (Step 2) and validating the plan (Step 3) — checklist for registration gaps |
