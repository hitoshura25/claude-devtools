---
description: Start feature development with planning and quality gates
---

# Develop

Start a new feature with proper planning and quality enforcement.

## Prerequisites

- Superpowers plugin installed for TDD and planning methodology
- Project has test framework configured
- Project has lint tools configured

## Process

### Phase 1: Planning

**If requirements are unclear:**
- Use skill `superpowers:brainstorming`

**Create implementation plan:**
- Use skill `superpowers:writing-plans`
- Plan saved to `docs/plans/YYYY-MM-DD-feature-name.md`

### Phase 2: Implementation

**Execute plan with TDD:**
- Use skill `superpowers:executing-plans`
- Each task follows `superpowers:test-driven-development`

**The TDD cycle for each task:**
1. Write failing test
2. Verify it fails (MANDATORY)
3. Write minimal code to pass
4. Verify it passes (MANDATORY)
5. Refactor
6. Commit

### Phase 3: Verification

**Run all quality gates:**
- Use command `/devtools:quality-check`
- All gates must pass

### Phase 4: Completion

**Finish the branch:**
- Use skill `superpowers:finishing-a-development-branch`

## Critical Rule

```
NO FEATURE IS COMPLETE WITHOUT:
1. All tests passing
2. All lint checks passing
3. Security scan passing
4. AI review passing (if configured)
```

## Anti-Rationalization

| Excuse | Reality |
|--------|---------|
| "I know how to do this, skip planning" | Plans catch issues before coding. Always plan. |
| "TDD is slow" | TDD is faster than debugging. Always TDD. |
| "Tests can come later" | Tests-after prove nothing. Tests-first or delete code. |
| "Just a quick feature" | Quick features become tech debt. Follow process. |

## Red Flags - STOP

- Starting to code before plan exists
- Writing implementation before test
- Skipping quality gates "just this once"
- Committing without running tests

**If you catch yourself doing any of these: STOP. Start over.**
