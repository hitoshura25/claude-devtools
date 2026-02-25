---
description: Design a feature and produce an implementation plan for agent-ready task decomposition
---

# Plan

Design a feature through collaborative brainstorming, then produce an implementation plan optimized for decomposition into agent-ready task files for local coding agents.

## Usage

```
/devtools:plan [feature description]
```

**Examples:**
```
/devtools:plan Add WebAuthn registration endpoint
/devtools:plan Refactor auth middleware to support JWT and session tokens
/devtools:plan                    # Start brainstorming without a topic
```

## Process

Use skill `devtools:implementation-planning` — it handles the full pipeline:

1. **Explore the idea** — uses `superpowers:brainstorming` for collaborative design, stopping after the design doc is committed (does not follow brainstorming's "After the Design" handoff to writing-plans)
2. **Write the implementation plan** — optimized for clean task decomposition, replacing `superpowers:writing-plans` with a format aware of downstream agent constraints
3. **Validate wiring completeness** — catch registration gaps before decomposition
4. **Hand off** — offer to decompose into agent-ready task files via `devtools:agent-ready-plans`, or let the user review the plan first

## What This Command Does NOT Do

- Does NOT implement any code
- Does NOT run tests or quality gates
- Does NOT touch any source files

This command is purely planning and documentation. Implementation is delegated to the agent of your choice.
