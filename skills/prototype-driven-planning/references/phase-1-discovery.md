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

## Identifying Integration Boundaries and Risks

Don't jump straight to "the one core risk." First, map out every integration
boundary the feature touches — every external service, API, SDK, data format,
or protocol involved. Then categorize each one.

### Step 1: List all integration boundaries

Read the feature description carefully. Every verb is a potential integration
boundary. For example, "Airflow downloads, parses, and feeds data" has three:
downloading (Google Drive API), parsing (SQLite schema), and feeding (RabbitMQ
publishing).

Also consider:
- External service APIs (REST, gRPC, GraphQL)
- Authentication/authorization flows (OAuth, service accounts, API keys)
- Data format parsing (custom schemas, protocols, wire formats)
- SDK/library integration (does the library actually work as documented?)
- Infrastructure interaction (Docker, message brokers, databases, cloud services)
- Framework-specific behavior (Airflow operators, React Native bridges, etc.)

### Step 2: Categorize each boundary

For each integration boundary, ask: **"Has this exact integration been proven to
work in this project before?"**

- **Unvalidated** — the project has never done this before, OR it uses a library/SDK
  the project hasn't used before. These carry real risk even if they *seem*
  straightforward. Include in the prototype scope.
- **Previously validated** — the project already has working code that does this
  exact thing (not something similar — the same thing). Can safely defer.
  Reference the existing code that proves it.
- **Genuinely trivial** — standard language features with no integration surface
  area (file I/O, string manipulation, basic data structures). Can safely defer.

The key distinction: **"I think this API is easy to use" is NOT the same as
"this project has already proven this API works."** The former is an unvalidated
assumption. OAuth flows, provider-specific SDKs, authentication patterns, and
framework-specific hooks all have integration surface area that only shows up
when you actually build against them.

### Step 3: Identify the core risk and integration risks

- **Core technical risk**: The single question whose answer determines feasibility.
  This is always in scope for the prototype.
- **Integration risks**: Unvalidated boundaries that are likely to cause implementation
  problems if not tested. These should be included in the prototype scope unless
  there's a clear reason to defer (e.g., requires credentials that aren't available,
  requires hardware that isn't present).

### Examples

**Feature**: "Airflow downloads from Google Drive, parses SQLite, publishes to RabbitMQ"

| Boundary | Category | Reason |
|---|---|---|
| SQLite schema parsing | **Core risk** | Unknown schema, custom data formats, unit conversions |
| Google Drive download | **Integration risk** | Project has never used Google Drive API or `apache-airflow-providers-google` |
| RabbitMQ publishing | Previously validated | `services/message-queue/publisher/` already does this |
| Airflow DAG wiring | **Integration risk** | Project has Airflow scaffolding but no proven running DAG |

**Feature**: "Add biometric login to the Android app"

| Boundary | Category | Reason |
|---|---|---|
| Biometric prompt API | **Core risk** | Never used, Android version compatibility unknown |
| Credential storage | **Integration risk** | EncryptedSharedPreferences vs AndroidKeyStore is a real design choice |
| Navigation to login screen | Previously validated | App already has navigation patterns |
| Network auth token refresh | Previously validated | App already has token refresh logic |

### What is genuinely NOT a risk

- "Can we write CRUD endpoints?" (yes, always — no integration surface area)
- "Can we add a new database table?" (yes, always)
- "Can we create a new React component?" (yes, always)
- Anything using only standard language features with no external integration

## Research

Research should be targeted at the identified risks, not broad surveys.

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
answer the right question. Critically, it must list what is being deferred and why,
so the user can override.

### Template for the proposal

```
## Prototype Proposal: <feature-name>

**Integration boundaries identified**:

| Boundary | Category | In prototype? |
|---|---|---|
| <boundary 1> | Core risk | Yes |
| <boundary 2> | Integration risk | Yes |
| <boundary 3> | Previously validated | No — proven by <existing code reference> |
| <boundary 4> | Integration risk | No — requires <unavailable resource> |

**Core risk being tested**: <one sentence>

**What the prototype will do**:
- <specific behavior 1>
- <specific behavior 2>

**What the prototype will NOT do**:
- No error handling beyond what's needed to run
- No edge cases
- <other explicit exclusions>

**Deferred risks** (not in prototype — confirm these are OK to skip):
- <boundary> — deferred because <reason>. If you want this validated, say so.

**Files to create**:
- prototypes/<feature-name>/<file1> — <purpose>
- prototypes/<feature-name>/<file2> — <purpose>

**How to validate**: <how we'll know it works>
```

The "Deferred risks" section is important. It makes the user aware of what is NOT
being tested and gives them an explicit opportunity to say "actually, include that."
This prevents the model from silently dismissing integration risks as "just
configuration."
