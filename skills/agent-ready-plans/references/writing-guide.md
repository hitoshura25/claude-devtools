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
