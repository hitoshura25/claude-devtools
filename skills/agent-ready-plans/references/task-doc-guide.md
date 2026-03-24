# Task Document Guide

How to write task documents that small models (7B-32B parameters) can execute successfully. Small models follow precise instructions well but struggle with ambiguity, inference, and connecting dots across context.

---

## Core Principles

**Be explicit, not clever.** Spell out every interface contract precisely. Instead of "follow the same pattern as the previous component", specify the exact class/function name, method signatures, and behavioral requirements.

**Show the base class call site for abstract methods.** The model only sees the abstract signature — not how the base class calls it. For every abstract method the task implements, include one line showing the concrete call:

```
# From base.process() — called once per item returned by _query():
result = self._transform(item)  # item is a single Row, not a list
```

This applies to any abstract/interface pattern: parsers, handlers, strategies, validators. One line prevents the model from assuming the wrong type, cardinality, or calling convention.

**Wiring task Behavior sections must use code snippets for all callable bodies — no prose.** Unconditional, no length judgement needed. Prose descriptions produce one-liner transcriptions that exceed line-length limits, triggering lint spirals that consume the model's reflection budget. Show the code; let the model copy it.

```
# WRONG — prose description that the model transcribes as a one-liner:
# "fetches the artifact path from the previous step and extracts it"

# CORRECT — show the exact callable body as code:
artifact_path = get_upstream_output(
    step_id="download",
    key="artifact_path",
)
extract_archive(artifact_path, dest_dir)
```

This rule applies only to **wiring task Behavior sections**. Component tasks use interface contracts and behavioral specs — the model writes the implementation to pass the pre-written tests.

**Interface contracts, not implementation code.** For component tasks: define class/function names, signatures with type annotations, and behavioral specs. No method bodies.

**Tests are on disk, not in the task doc.** Test files are written and validated during implementation planning and saved to disk. Task docs reference the test file by path — they do not embed a copy. Embedding creates a second source of truth that can diverge from the validated file due to LLM non-determinism at generation time.

**Environment constraints over mock instructions.** State what's mocked and what can't make real connections. Tests already handle mock wiring.

**Minimize context requirements.** Include the interface of dependencies in the task doc (class name, key method signatures, import path) so the model doesn't need to read other files.

**Keep task docs under 2000 tokens.** Small model context windows are limited. Removing embedded test code helps significantly here.

**Break long literals across lines in Behavior sections.** Any string literal or nested dict that could exceed the project line-length limit (typically 88 chars) must be shown in multi-line form in the task doc's Behavior section. The model copies whatever form it reads. Single-line forms that look short may exceed the limit once variable names, indentation, and closing punctuation are added. This applies to SQL queries, Avro/JSON schemas, format strings with interpolations, and nested dict literals. Show them broken across lines; the model will copy the form.

```
# WRONG — single-line literal exceeds line-length limit after indentation:
config = {"type": "record", "name": "Measurement", "fields": [{"name": "value", "type": "float"}, {"name": "timestamp", "type": {"type": "record", "name": "Time", "fields": [{"name": "epochMillis", "type": "long"}]}}]}

# CORRECT — multi-line form the model can copy safely:
config = {
    "type": "record",
    "name": "Measurement",
    "fields": [
        {"name": "value", "type": "float"},
        {
            "name": "timestamp",
            "type": {
                "type": "record",
                "name": "Time",
                "fields": [{"name": "epochMillis", "type": "long"}],
            },
        },
    ],
}
```

**Always include the output constraint.** Small models often append conversational text after code. Every task's Project Context section must end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

**Include validated schemas in Behavior sections when tests check schema parsing.** If a test validates schema structure, the task doc must include the exact, validated schema in the Behavior section. The implementing model cannot reliably construct schemas that satisfy library-specific constraints. The validated schema was produced during implementation planning — copy it verbatim into the task doc.

---

## Deferred Tasks vs Service-Gated Tasks

Two distinct categories. Conflating them causes unnecessary runner pauses.

### Deferred Tasks — task doc cannot be written upfront

A task is **deferred** only when its content depends on runtime artifacts that don't yet exist (actual class names, module paths, function signatures from earlier tasks).

Wiring tasks are now generated upfront with `deferred: false` because interface contracts define exact class names and `import_integrity` catches drift. A wiring task may still be deferred if interface contracts are loosely specified.

### Service-Gated Tasks — execution needs live services

Integration tests are **not deferred** — they can be fully written before the run. Mark with `"requires_services"` in the manifest. The runner checks service health and **exits with an error** if services are unavailable — it does not skip.

**Rule for deciding:**

| Condition | Classification |
|-----------|---------------|
| Task doc depends on runtime artifacts from earlier tasks | `deferred: true` |
| Task doc is complete upfront; execution needs live services | `requires_services: [...]`, `deferred: false` |
| Task runs in isolation with mocks | Standard task |

---

## Task Splitting Guidelines

If a task doc exceeds ~2000 tokens, split by responsibility (e.g., "create config" and "create the component" as separate tasks). **Never split the implementation from its test file** — the model needs both to do its job.

---

## Complexity Ratings

| Rating | Description | Example |
|--------|-------------|---------|
| **simple** | Create files, no logic, boilerplate | Config files, Dockerfile |
| **moderate** | One class/module with clear logic | A client wrapper, a parser |
| **complex** | Multiple interacting components, edge cases | Orchestrator assembly, routing |

---

## Adapting for Different Agents

Task docs are agent-agnostic markdown. The same files work with aider + LMStudio, Claude Code, Codex CLI, or any coding agent with a message-file param. To add a new backend, change the runner script.
