# Task [N]: [Descriptive Name]

> **INSTRUCTION TO AGENT:** This task has been pre-approved. Create ALL files listed below immediately. Do not describe what you would do — actually create each file. Do not ask for confirmation or permission. Output every file using the required edit format.

**Phase:** [N] - [Phase Name]
**Dependencies:** [Task numbers or "None"]
**Blocking:** [What this task blocks]

## Objective

[1-2 sentences: what this task accomplishes and why]

## Context

[Brief context. For scaffolding tasks this is usually short.]

## Files to Create

Create each file at the exact path shown. Every `__init__.py` file should contain only a single-line comment. `.gitkeep` files should be empty.

- `src/package/__init__.py` — contains: `# package`
- `src/package/subpackage/__init__.py` — contains: `# subpackage`
- `tests/__init__.py` — contains: `# tests`
- `data/.gitkeep` — empty file

## Verification

```bash
find src/ -type f | sort
```

Expected output:
```
[list exact expected files]
```

## Acceptance Criteria

- [ ] All files above exist at the exact paths shown
- [ ] Directory structure is correct
