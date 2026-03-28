# Phase 1: Design Doc Analysis — Detailed Guidance

## Reading the Design Doc

The design doc follows a consistent template (from `prototype-driven-planning`).
Parse it section by section, extracting what each section tells you about tasks.

### Section → Task Mapping

| Design Doc Section | What it tells you about tasks |
|-------------------|-------------------------------|
| Architecture Overview → Components | Each component is a natural task boundary |
| Architecture Overview → Interactions | Interaction patterns reveal integration tasks |
| Data Model | Data structures inform core tasks and test fixtures |
| Dependencies | New dependencies become scaffold tasks |
| Testing Strategy | Test infrastructure and patterns become testing-phase tasks |
| Containerization | Dockerfile and config become infrastructure tasks |
| Security Posture | Security concerns get distributed across relevant tasks |
| Deployment Strategy | Deployment config becomes infrastructure tasks |
| Open Questions | Anything here should NOT become a task — flag it to the user |

### What to Watch For

**Components that are actually multiple tasks.** A "Health Sync Service" component
might need: (1) a data model task, (2) an API client task, (3) a service
orchestration task, and (4) an endpoint wiring task. Don't create one giant task
per component.

**Hidden dependencies.** The design doc might not explicitly state that component A
imports from component B, but reading the interactions section reveals it. These
implicit dependencies must become explicit `depends_on` entries.

**Config and setup that's easy to forget.** Dependencies, environment variables,
config files, and `__init__.py` files are boring but critical. If the implementing
model can't import the module it just built because `__init__.py` is missing,
the whole task fails. Include setup in scaffold tasks.

## Inventorying the Prototype

List every file in `prototypes/<feature-name>/` and understand its role:

```
prototypes/health-data-sync/
├── README.md              → Documents what the prototype proved
├── main.py                → Entry point, demonstrates core flow
├── fetch.py               → API client pattern
├── transform.py           → Data transformation pattern
├── .ruff.toml             → Lint config (copy to production)
├── tests/
│   ├── conftest.py        → Fixture patterns
│   └── test_transform.py  → Test patterns
└── Dockerfile             → Container setup pattern
```

For each file, note:
- **What pattern it demonstrates** (this becomes `what_to_reference`)
- **Whether the pattern transfers to production directly** or needs adaptation
- **Any surprises documented in the README** (these inform task descriptions)

## Identifying Component Boundaries

Read the Architecture Overview's Components section. Each component typically
maps to one or more tasks. The deciding factor is **cognitive scope** — can a
local model (~30B parameters) hold this entire component in its working context
at once?

### Splitting heuristics

**Split when:**
- A component touches more than 3-4 files
- A component has both "data model" and "business logic" responsibilities
- A component has external integration points (API calls, database access)
  that are separately testable
- The component's tests alone would be complex enough to be their own task

**Merge when:**
- Two "components" are really just one file and its test
- A component is pure configuration (a config class, an env file)
- A component is a thin wrapper with no real logic

### Phase assignment rules of thumb

| If the task... | Assign phase... |
|----------------|-----------------|
| Creates project directories, `__init__.py`, config files, installs deps | `scaffold` |
| Implements a data model, business logic, algorithm, or utility | `core` |
| Wires components together, creates API endpoints, builds orchestration | `integration` |
| Creates test fixtures, integration tests, or test infrastructure | `testing` |
| Creates Dockerfile, CI config, deployment scripts | `infrastructure` |

## Mapping Dependencies

Build the dependency graph by asking for each task: "What files must already
exist on disk for this task to succeed?"

### Common dependency patterns

- **Scaffold → everything.** Most core tasks depend on the scaffold task that
  creates the package structure and `__init__.py` files.
- **Core → core.** If component A imports from component B, the task creating B
  must complete first.
- **Integration → core.** Integration tasks wire core components together, so
  they depend on all the core tasks they wire.
- **Testing → core + integration.** Test tasks import the code they test.
- **Infrastructure → integration.** The Dockerfile and deployment config need
  the full application to exist.

### Interface dependencies

A subtlety: if task B will `import` from a module created by task A in
production — even if task B's code could technically be written without that
file existing yet — task B should still depend on task A. The reason is that
the implementing model benefits from being able to read the real module it's
importing from, rather than guessing at its interface.

For example, if a watermark store will `from config.settings import Settings`
in production, it should depend on the settings task. This ensures the
implementing model can read the actual `Settings` class definition and write
compatible code, rather than hardcoding assumptions that might not match.

Err toward including interface dependencies. A local model that can read the
real module it depends on produces more reliable code than one working from
a description alone.

### Visualizing the graph

When presenting the decomposition to the user, show the dependency graph as a
simple text diagram:

```
task-01 (scaffold)
├── task-02 (core: data model)
│   ├── task-04 (core: API client)
│   │   └── task-06 (integration: service orchestration)
│   │       └── task-08 (infrastructure: Dockerfile)
│   └── task-05 (core: transformer)
│       └── task-06
├── task-03 (core: config)
│   └── task-04
└── task-07 (testing: integration tests)
    └── task-06
```

## Surfacing Ambiguities

During analysis, you'll often find places where the design doc leaves room for
interpretation — multiple valid approaches, underspecified behavior, or open
questions that affect how tasks should be structured.

Collect these as **explicit numbered questions** and present them alongside the
decomposition proposal. Don't bury them in prose — the user needs to see them
clearly and respond to each one before task generation proceeds.

### Common sources of ambiguity

- **Storage backend choices** not resolved in the design doc (SQLite vs
  PostgreSQL, file-based vs database-backed)
- **Naming conventions** not specified (exact filenames, service names,
  exchange/queue names)
- **Scope boundaries** where the design doc says "support X" but doesn't
  specify how much of X (single-user vs multi-user, one device vs many)
- **Idempotency strategy** mentioned but the mechanism not specified
- **Prototype limitations** listed in the design doc that need a production
  decision (which limitations to address now vs defer)

### Proposal format with questions

Present questions as a numbered list after the dependency graph, so the user
can respond by number:

```
### Questions (please respond by number)

1. The design doc mentions a watermark store but doesn't specify the backend.
   The project already has a PostgreSQL database — should the watermark table
   live there, or use a separate SQLite file on the Airflow worker volume?

2. The prototype doesn't handle Google Drive API integration (it uses a local
   file path). Should task-05 implement the full Drive API download, or use
   a simplified approach for the initial implementation?

3. The design doc lists "deduplication" as a prototype limitation. Should we
   address this now (via idempotency keys in published messages) or defer it?
```

This saves a round-trip: the user answers all questions in one message, and
task generation proceeds with clear decisions rather than assumptions.

## Proposing the Decomposition

Present the proposal in this format:

```
## Task Decomposition Proposal: <feature-name>

**Source**: `docs/design/<feature-name>.md`
**Prototype**: `prototypes/<feature-name>/`
**Total tasks**: N

### Phase Breakdown
- Scaffold: N tasks
- Core: N tasks
- Integration: N tasks
- Testing: N tasks
- Infrastructure: N tasks

### Dependency Graph
<text diagram>

### Questions (please respond by number)
<numbered list of ambiguities>

### Flags
- <Any design doc sections that feel underspecified>
- <Any open questions from the design doc that affect task definition>
```
