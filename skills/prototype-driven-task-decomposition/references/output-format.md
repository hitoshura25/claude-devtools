# Phase 3: Validation and Output — Detailed Guidance

## Output Structure

The skill produces this directory structure:

```
tasks/<feature-name>/
├── tasks.json                    # Machine-readable, schema-validated
├── task-01-<slug>.md             # Human-readable view of task 01
├── task-02-<slug>.md
├── ...
└── task-NN-<slug>.md
```

The `<slug>` is derived from the task title by lowercasing, replacing spaces with
hyphens, and stripping special characters. Keep slugs short (3-4 words max).

## JSON Output (`tasks.json`)

The JSON file conforms to the `TaskDecomposition` schema in `scripts/task_schema.py`.
It's the source of truth for the implementation pipeline.

### Structure

```json
{
  "feature_name": "health-data-sync",
  "design_doc_path": "docs/design/health-data-sync.md",
  "prototype_path": "prototypes/health-data-sync/",
  "summary": "Implements a health data synchronization service...",
  "tasks": [
    {
      "id": "task-01",
      "title": "Create project scaffold and package structure",
      "phase": "scaffold",
      "description": "Set up the directory structure...",
      "depends_on": [],
      "files": [
        {
          "path": "src/health_sync/__init__.py",
          "operation": "create",
          "description": "Package init — exports the public API"
        }
      ],
      "prototype_references": [],
      "tests": [],
      "acceptance_criteria": [
        "Package is importable: `import health_sync` succeeds",
        "Lint passes with zero errors"
      ],
      "security_considerations": []
    }
  ]
}
```

### Validation

Before writing the JSON file, validate mentally (or explicitly) against these
constraints from the schema:

1. Every `depends_on` entry references an existing task `id`
2. No circular dependencies exist
3. Every task has at least one file in `files`
4. Every task has at least one entry in `acceptance_criteria`
5. Every task has "lint passes" in acceptance criteria (the schema auto-adds it,
   but include it explicitly for clarity)
6. Task IDs are unique
7. File paths are project-relative (no absolute paths)

## Markdown Output (`task-NN-<slug>.md`)

Each markdown file is a human-readable view of one task. The format should be
consistent across all tasks for easy scanning.

### Template

```markdown
# Task NN: <Title>

**Phase**: <phase>
**Depends on**: <comma-separated task IDs, or "none">

## Description

<description from the task — the self-contained context>

## Files

| Path | Operation | Description |
|------|-----------|-------------|
| `<path>` | create/modify | <description> |

## Prototype References

| File | What to Reference |
|------|-------------------|
| `<file>` | <what_to_reference> |

<or "No prototype references for this task." if empty>

## Tests

| Test | File | Type |
|------|------|------|
| <description> | `<test_file>` | unit/integration/e2e |

<or "No tests for this task." if empty>

## Acceptance Criteria

- <criterion 1>
- <criterion 2>
- Lint passes with zero errors

## Security Considerations

| Concern | Mitigation |
|---------|------------|
| <concern> | <mitigation> |

<or "No security considerations for this task." if empty>
```

### File naming

- Use zero-padded task numbers: `task-01`, `task-02`, ..., `task-12`
- Slug from title: "Create project scaffold" → `task-01-project-scaffold.md`
- Keep the slug to 3-4 words maximum

## Summary Table

After generating all files, print a summary table to the conversation:

```
## Task Summary: <feature-name>

| ID | Title | Phase | Depends On | Files | Tests |
|----|-------|-------|------------|-------|-------|
| task-01 | Create project scaffold | scaffold | — | 4 | 0 |
| task-02 | Implement data model | core | task-01 | 2 | 3 |
| ...

Total: N tasks across M phases
Dependency depth: K (longest chain from root to leaf)

Schema: The task schema is defined in `scripts/task_schema.py` (PydanticAI).
To validate: `python -c "from task_schema import TaskDecomposition; TaskDecomposition.model_validate_json(open('tasks.json').read())"`
```

The "dependency depth" metric helps the user understand the critical path.
A very deep chain (>5) might indicate over-fragmentation; a very flat graph
(depth 1-2) might indicate under-decomposition.

The schema pointer and validation command help the user understand the
relationship between the JSON output and the PydanticAI schema — especially
useful for people encountering the pipeline for the first time.

## Interrupted Generation Recovery

If generation is interrupted mid-way (rate limits, session timeouts, user
needs to step away), the skill should be able to resume cleanly:

- **If interrupted during JSON generation**: The incomplete `tasks.json` is
  invalid. Delete it and regenerate from scratch. The task definitions live
  in the model's context, so regeneration is straightforward.

- **If interrupted during markdown generation**: `tasks.json` is complete but
  some markdown files are missing. List which `task-NN-*.md` files exist and
  which are missing, then generate only the missing ones.

- **If the user says "continue"**: Check what exists in `tasks/<feature-name>/`.
  If `tasks.json` is present and valid, generate only missing markdown files
  and print the summary. If `tasks.json` is missing or invalid, regenerate
  everything.

The key principle: `tasks.json` is always written first (it's the source of
truth). Markdown files are derived from it. If the JSON is intact, recovery
is just regenerating the markdown views.

## Editing Workflow

After presenting the summary, the user may want to adjust tasks. Common requests:

- **Split a task**: Create two new tasks with the next available IDs. Update
  any `depends_on` references that pointed to the old task.
- **Merge tasks**: Combine file lists, tests, and acceptance criteria. Remove
  one task ID and update dependencies.
- **Reorder**: Change `depends_on` relationships and potentially reassign phases.
- **Add detail**: Expand a task's description, add prototype references, or
  add security considerations.

After any edit, regenerate both `tasks.json` and the affected markdown files.
Remind the user that `tasks.json` is the source of truth.

## JSON-Markdown Sync Warning

The markdown files are a *convenience view*. If someone edits a markdown file
by hand, those changes are NOT reflected in `tasks.json`. The implementation
pipeline reads `tasks.json`, not the markdown files.

If the user wants to make hand edits, advise them to either:
1. Edit `tasks.json` directly and regenerate the markdown files
2. Tell you the changes and you'll update both
3. Edit the markdown for their own notes, understanding the pipeline won't see it

Surface this clearly — a mismatch between JSON and markdown will cause confusion
downstream.
