# Phase 1: Discovery — Detailed Guidance

## Project Inventory

Before proposing anything, understand what exists. The goal is to avoid building
something that conflicts with existing patterns or duplicates existing functionality.

### What to examine

- **Project structure**: Directory layout, module organization, monorepo vs single-app
- **Dependencies**: Package manager files (requirements.txt, pyproject.toml, package.json,
  Cargo.toml, build.gradle). What frameworks and libraries are already in use?
- **Configuration**: Environment variables, config files, CI/CD pipelines
- **Existing patterns**: How does the project handle things like database access, API
  calls, error handling, logging? The prototype should follow existing conventions
  where possible.
- **Entry points**: Where does the application start? What are the key interfaces?
- **Test infrastructure**: What testing framework is in use? What does the test layout
  look like? Are there fixtures, mocks, or test utilities already established?

### How to examine

Use file reading, directory listing, and grep/search tools. Don't read every file —
be targeted. Start with:
1. Root-level config files (READMEs, package manifests, Dockerfiles, CI configs)
2. Top-level directory listing to understand module boundaries
3. A representative source file in the area where the new feature would live
4. Existing test files to understand testing patterns

## Identifying Core Technical Risk

The "core technical risk" is the single technical question whose answer determines
whether the feature is feasible. Everything else is implementation detail.

### Examples of core technical risk

- "Can we get real-time data from this API within acceptable latency?"
- "Does this library actually support the data format we need?"
- "Can the JNI bridge pass complex data structures without corruption?"
- "Will the ORM handle this query pattern without N+1 problems?"

### What is NOT core technical risk

- "Can we write CRUD endpoints?" (yes, always)
- "Can we add a new database table?" (yes, always)
- "Can we write unit tests?" (yes, always)
- Anything that's standard engineering with known solutions

If the feature has no real technical risk — if it's straightforward CRUD or glue code —
say so. The prototype phase still has value (it grounds the design doc in reality), but
the scope can be minimal.

## Research

Research should be targeted at the specific technical risk, not broad surveys.

### Good research targets

- Official documentation for the specific library/API/framework involved
- Known issues, limitations, or gotchas with the technology
- Authentication/authorization patterns required by external services
- Data format specifications (schemas, protocols, wire formats)
- Performance characteristics or constraints

### Research output

Summarize findings concisely. Include:
- Key constraints or limitations discovered
- Patterns recommended by official documentation
- Anything that changes the prototype scope
- Links to relevant documentation (if web search was used)

## Proposing Prototype Scope

The proposal should be concrete enough that the user can evaluate whether it will
answer the right question.

### Template for the proposal

```
## Prototype Proposal: <feature-name>

**Core risk being tested**: <one sentence>

**What the prototype will do**:
- <specific behavior 1>
- <specific behavior 2>

**What the prototype will NOT do**:
- No tests
- No error handling beyond what's needed to run
- No edge cases
- <other explicit exclusions>

**Files to create**:
- prototypes/<feature-name>/<file1> — <purpose>
- prototypes/<feature-name>/<file2> — <purpose>

**How to validate**: <how we'll know it works>
```
