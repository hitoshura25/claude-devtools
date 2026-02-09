---
description: Design a feature and produce agent-ready task files for local coding models
---

# Plan

Design a feature through collaborative brainstorming, then produce an implementation plan broken into individual task files optimized for local coding agents (Aider, Continue, Cline/Roo Code, Goose, etc.).

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

### Phase 1: Design (Claude)

**If requirements are unclear or no feature description provided:**
- Use skill `superpowers:brainstorming`

**Create implementation plan:**
- Use skill `superpowers:writing-plans`
- Plan saved to `docs/plans/YYYY-MM-DD-feature-name.md`

### Phase 2: Task Decomposition (Claude)

**Break the plan into agent-ready task files:**
- Use skill `devtools:agent-ready-plans`
- Creates `docs/plans/YYYY-MM-DD-feature-name/` directory
- Each task becomes a standalone markdown file
- Files are numbered and dependency-ordered

### Phase 3: Handoff

**Present the task files and suggest execution:**

> Plan complete. Created N task files in `docs/plans/YYYY-MM-DD-feature-name/`
>
> **Execute with a local agent:**
> ```bash
> # Aider (recommended)
> aider --read docs/plans/YYYY-MM-DD-feature-name/task-01-name.md
>
> # Or feed all context
> aider --read docs/plans/YYYY-MM-DD-feature-name/00-context.md \
>       --read docs/plans/YYYY-MM-DD-feature-name/task-01-name.md
> ```
>
> **Or delegate via SERA:**
> ```
> /devtools:sera 1
> ```
>
> **Or execute with Claude:**
> ```
> /devtools:develop
> ```

## What This Command Does NOT Do

- Does NOT implement any code
- Does NOT run tests or quality gates
- Does NOT touch any source files

This command is purely planning and documentation. Implementation is delegated to the agent of your choice.

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "I can just start coding from the design doc" | Local models need focused, self-contained context. Task files prevent hallucination. |
| "One big plan file is fine for Aider" | Smaller context = better output from local models. Always decompose. |
| "Skip brainstorming, I know what I want" | 5 minutes of design prevents hours of rework. Always brainstorm. |
| "The design doc is enough" | Design docs explain WHAT. Task files explain HOW with exact paths, code, and tests. |
