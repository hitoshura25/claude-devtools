# Writing Task Docs for Small Models

Small models (7B-32B parameters) need a very different instruction style than Claude. They can follow precise instructions well, but struggle with ambiguity, inference, and connecting dots across context.

## Core Principles

**Be explicit, not clever.** Spell out every step. Instead of "follow the same pattern as the steps extractor", copy the pattern inline. The model shouldn't need to figure out what you mean.

**One thing at a time.** Each instruction should do exactly one thing. "Create file X with this content" — not "Create the test file, run it, then create the implementation."

**Full code always.** Provide the complete implementation, not placeholders. "Implement the transform method" will confuse a small model. Give it the actual method body.

**Minimize context requirements.** The model shouldn't need to read other files to understand what to do. If it needs an interface, include the interface definition in the task doc.

**Concrete over abstract.** `Create a class StepsExtractor that inherits from BaseRecordExtractor` with the full class body is better than "Create an extractor following the base class pattern."

**Keep task docs under 2000 tokens.** Small model context windows are limited. If a task would exceed this, split it into sub-tasks (see Splitting Guidelines below).

**Write lint-clean code.** Since the runner enables `--auto-lint`, any lint violations in task docs cause aider to enter a fix loop. Write clean code so aider focuses on creating files, not fixing style.

**Include tests for every task.** Since the runner enables `--auto-test`, every task needs tests that pass after the code is created. If the original plan doesn't specify tests, write them.

**Always include the output constraint.** Small models often append conversational text like "To test this, run..." or "If you want to run the tests...". Aider's `whole` edit format interprets these as filenames and creates junk files at the project root. Every task's Project Context section must end with: `**Output constraint:** Respond with ONLY the file changes. Do not include explanations, test commands, suggestions, or any conversational text.`

## Deferred Tasks

Some tasks cannot be accurately written before the implementation tasks run, because they depend on the exact interfaces, signatures, or structures that earlier tasks produce. Small models may deviate from the plan — slightly different parameter names, return types, class hierarchies — and a task doc written against the planned interface will fail against the actual one.

**Mark a task as deferred when it:**
- Tests functions or classes created by multiple earlier tasks (integration tests, end-to-end tests)
- Wires together components whose exact APIs are defined by other tasks (DAG assembly that imports from many modules, router/dispatcher that calls multiple handlers)
- Modifies files created by earlier tasks in ways that depend on their exact content (adding registrations, updating import maps)

**No need to defer tasks that:**
- Only test code within the same task doc (unit tests) — these are self-contained by design
- Create standalone components with no cross-task interface dependencies
- Follow a well-defined base class pattern where the interface is fixed (e.g., all extractors implement the same ABC — the contract is known upfront)

**How deferred tasks work:**

1. During initial generation (Step 5), create a manifest entry with `"deferred": true`, `"deferred_reason"`, and `"depends_on"` listing the task IDs it depends on. Skip creating the `.md` task doc file — it will be generated later from real code.
2. The runner skips deferred tasks and stops after the last non-deferred task completes.
3. The user invokes Claude Code to generate the deferred task docs. Claude Code reads the actual implementation files (not the plan) and writes task docs with real function signatures, real parameter names, and real import paths.
4. The user resumes the runner with `--start N` to execute the deferred tasks through aider as normal.

**Example manifest entry for a deferred task:**
```json
{
  "file": "25-task-12.1-dag-integration-test.md",
  "task_id": "12.1",
  "title": "DAG Integration Tests",
  "phase": "Integration Testing",
  "files_created": ["services/airflow-ingestion/tests/test_dag_integration.py"],
  "estimated_complexity": "complex",
  "deferred": true,
  "deferred_reason": "Tests real function signatures from task_functions.py, watermark_manager.py, and all extractors. Must use actual interfaces, not planned ones.",
  "depends_on": ["8.1", "9.1", "10.1", "11.1"]
}
```

When generating a deferred task doc after implementation, follow the same task-template.md structure but read the actual source files for imports, signatures, and parameter names. Do not reference the original plan for interface details — the implementation is the source of truth.

## Task Splitting Guidelines

If a single task from the implementation plan would produce a task doc exceeding ~2000 tokens:

1. Split the test and implementation into separate task docs
2. Keep "create file" and "modify file" as separate tasks
3. For tasks with 3+ files, consider one task per file

**Example split:**
```
Original: Task 5.3 — Heart Rate Extractor (with Series Join)
Split into:
  - 08-task-5.3a-heart-rate-extractor-tests.md
  - 09-task-5.3b-heart-rate-extractor-implementation.md
```

Update the manifest to reflect the split and keep sequential numbering intact.

## Complexity Ratings

Used in the manifest and task headers to set expectations:

| Rating | Description | Example |
|--------|-------------|---------|
| **simple** | Create files, no logic, boilerplate | Directory scaffolding, requirements.txt, Dockerfile |
| **moderate** | One class/module with clear logic, has tests | A record extractor, a parser, a client wrapper |
| **complex** | Multiple interacting components, joins, edge cases | DAG assembly, consumer routing with format detection |

## Adapting for Different Agents

The task docs are agent-agnostic markdown. While the runner defaults to aider + LMStudio, the same files work with:

- **Claude Code** — `cat task-file.md | claude-code` or paste into a session
- **Codex CLI** — use as input prompt
- **Any agent with a message-file param** — the format is universal

To add a new agent backend, change the command and arguments in the runner script.
