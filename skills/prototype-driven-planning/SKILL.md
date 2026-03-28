---
name: prototype-driven-planning
description: >
  Plan a feature by building a working prototype first, then generating a design doc
  grounded in reality. Use this skill when the user explicitly asks for prototype-first
  planning, prototype-driven design, or invokes /prototype-driven-planning. Do NOT
  trigger on general planning or architecture requests — only when the user wants to
  validate ideas through working code before writing specifications.
---

# Prototype-Driven Planning

Build a working prototype first, then write a design doc grounded in what actually works —
not speculation.

This skill runs three phases with a pause between each for user confirmation.
Never skip a pause or combine phases without explicit user approval.

## Quick Reference

| Phase | Purpose | Output |
|-------|---------|--------|
| 1. Discovery | Understand the project, map integration boundaries, identify risks | Summary of findings + proposed prototype scope |
| 2. Tracer Bullet | Build minimum code, validate toolchain, prove it works end-to-end | Working prototype in `prototypes/<feature>/` |
| 3. Design Doc | Architecture, testing, containers, security, deployment | `docs/design/<feature>-<YYYY-MM-DD>.md` |

## How to Start

The feature idea comes from `$ARGUMENTS`. If `$ARGUMENTS` is empty, ask the user
what feature they want to plan.

Derive a short kebab-case `<feature-name>` from the idea (e.g., "health data sync"
→ `health-data-sync`). Confirm the name with the user before proceeding.

## Phase 1: Discovery

Read `references/phase-1-discovery.md` for detailed guidance, then:

1. **Inventory the project.** Read the project structure, key config files, existing
   patterns, and dependencies. Understand what's already there before adding anything.

2. **Map integration boundaries.** List every external service, API, SDK, data format,
   or protocol the feature touches. Every verb in the feature description is a
   potential boundary ("downloads, parses, feeds" = three boundaries).

3. **Categorize each boundary.** For each one, determine:
   - **Core risk**: The single feasibility question. Always in prototype scope.
   - **Integration risk**: Unvalidated boundary with real surface area (OAuth,
     provider SDKs, framework hooks). Should be in prototype scope unless there's
     a clear reason to defer.
   - **Previously validated**: The project already has working code doing this
     exact thing. Can defer — cite the existing code.
   - **Genuinely trivial**: No integration surface area. Can defer.

   The key test: **"I think this API is easy" ≠ "this project has proven it works."**
   The former is an unvalidated assumption. Include it in the prototype.

4. **Research.** Investigate best practices for the technologies involved, focusing
   on identified risks.

5. **Propose the prototype scope.** Present to the user:
   - Integration boundary table (what's in scope, what's deferred, why)
   - What the prototype will prove
   - What it will NOT include
   - **Deferred risks with reasons** — so the user can override

**STOP.** Present your discovery findings and prototype proposal. The deferred
risks section is especially important — the user should confirm what to skip.
Wait for user confirmation before proceeding to Phase 2.

## Phase 2: Tracer Bullet Prototype

Read `references/phase-2-prototype.md` for detailed guidance, then:

### Step 1: Core Code

1. **Build the minimum code** in `prototypes/<feature-name>/` that proves the core
   technical risk and any integration risks included in the approved scope.

2. **Run it.** The prototype must actually execute. If it fails, iterate until it works.

3. **Validate.** Confirm the prototype proves what it was supposed to prove.

### Step 2: Toolchain Validation

The prototype isn't just about proving the feature works — it also proves the
development toolchain works. These steps ground the design doc's testing,
linting, and containerization sections in reality rather than speculation.

4. **Set up lint.** Configure linting for the prototype code, matching the project's
   existing lint tools if it has them. Run the linter and fix until it passes clean.

5. **Set up minimal tests.** Write the minimum tests needed to validate the
   prototype's core logic. Configure the test framework (matching the project's
   existing test setup if applicable). Run and confirm they pass. This validates
   that the test infrastructure works for this technology — fixture patterns,
   imports, mocking boundaries — before the design doc prescribes them.

6. **Set up a Dockerfile (if applicable).** Build a Dockerfile that packages the
   prototype and starts successfully. Skip for libraries, CLI tools, mobile apps,
   or features added to existing services. See the reference doc for detailed
   criteria on when to include vs skip.

### Step 3: End-to-End Validation

The prototype must be proven to work *from the outside*, not just internally.
The form this takes depends on the project type:

7. **Prove the prototype is usable in the way it will actually be used.** This is
   technology-dependent:
   - **Dockerized service**: A health check passes, or a simple request/response
     succeeds against the running container.
   - **Mobile app**: The app builds, installs, and a basic UI test confirms a
     screen renders.
   - **Library/SDK**: An external consumer can import and call the public API.
   - **CLI tool**: End-to-end invocation with real input produces expected output.
   - **Scheduled job/DAG**: The job runs to completion in its runtime environment
     (e.g., Airflow triggers and completes the DAG, not just "the script runs").

   Running code internally is necessary but not sufficient. The prototype must
   demonstrate that the thing works from the perspective of its actual consumer.

### Step 4: Cross-Cutting Research

8. **Research cross-cutting concerns.** Now that the core tech and toolchain work,
   research beyond what the prototype already validated:
   - Additional testing patterns (integration tests, service-gated tests)
   - Security-by-design principles relevant to this feature
   - Deployment considerations

**STOP.** Report what the prototype proved (core logic, toolchain, and end-to-end),
what you learned from research, and any surprises encountered during setup.
Wait for user confirmation before proceeding to Phase 3.

## Phase 3: Vetted Design Doc

Read `references/phase-3-design-doc.md` and `references/design-doc-template.md`, then:

1. **Generate the design doc** at `docs/design/<feature-name>-<YYYY-MM-DD>.md` (using today's date) following the
   template. Every section must be grounded in the prototype's reality. If the
   prototype didn't touch a concern (e.g., no database), say so — don't speculate.

2. **Cross-reference the prototype.** The design doc should explicitly reference
   the prototype path (`prototypes/<feature-name>/`) and point to specific files
   when describing patterns or decisions.

3. **Ensure consumability.** The design doc will eventually be consumed by a task
   decomposition phase (not built yet). Keep sections clearly bounded with
   consistent heading structure so a future parser can extract individual concerns.

**STOP.** Present the design doc for review. Walk through each section briefly
and ask for feedback.

## Principles

- **The prototype is a reference artifact.** Once complete, treat it as immutable.
  It's raw data from an experiment, not a living codebase. Don't go back and modify
  it — if something needs to change, that's a signal for the design doc, not a
  reason to patch the prototype.
- **Production code is a separate thing.** Future implementation copies patterns from
  the prototype into fresh production code. If something breaks, the prototype is
  still there for comparison.
- **Observe, don't predict.** The design doc describes what the prototype proved, not
  what the model thinks might work.
- **Prove it from the outside.** Running code internally is necessary but not
  sufficient. The prototype must work from the perspective of its actual consumer —
  whether that's a health check, a UI test, or an API call.
- **"Seems easy" is not "proven."** If the project hasn't done this exact integration
  before, it's an unvalidated risk. Don't silently dismiss integration boundaries
  as "just configuration" — surface them for the user to decide.
- **Research is phase-appropriate.** Phase 1 researches the problem space. Phase 2
  validates the toolchain and researches remaining concerns. Don't front-load
  research on concerns that might not matter.
