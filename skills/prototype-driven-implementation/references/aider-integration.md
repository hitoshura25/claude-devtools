# Aider Integration — Scripting Mode and Prompt Composition

## Aider CLI Reference for Pipeline Use

The pipeline invokes Aider in scripting mode — no interactive session, no chat.
Each task is a single `--message-file` invocation that exits after processing.

### Core Flags

| Flag | Purpose | Value |
|------|---------|-------|
| `--model` | LLM to use | `openai/<model-name>` or `lm_studio/<model-name>` |
| `--openai-api-base` | Model endpoint | From `MODELS[name]["api_base"]` |
| `--openai-api-key` | API key | From `MODELS[name]["api_key"]` (resolved at startup) |
| `--message-file` | Task prompt file | Absolute path to composed prompt |
| `--file` | Files Aider can edit | Paths relative to Aider's cwd |
| `--yes-always` | Skip all confirmations | (flag only) |
| `--no-git` | Pipeline manages git, not Aider | (flag only) |
| `--no-check-update` | Don't check for Aider updates | (flag only) |
| `--no-show-model-warnings` | Suppress model compatibility warnings | (flag only) |

### Working Directory and File Path Behavior

Aider runs all commands (lint, test, file editing) from its cwd. This has
two important consequences:

1. **`--file` paths are relative to cwd.** If Aider's cwd is
   `/project/services/my-service/` and you want it to edit
   `plugins/client.py`, pass `--file plugins/client.py`.

2. **`--lint-cmd` appends edited filenames relative to cwd.** After editing
   `plugins/client.py`, Aider runs `<lint-cmd> plugins/client.py`. The lint
   tool must be findable from that cwd (on PATH, in a local node_modules/.bin,
   in a venv, etc.).

This is why the pipeline sets Aider's cwd to the **service root** (the
directory where lint/test tools are installed), not the project root. The
pipeline rebases file paths from tasks.json (project-root-relative) to be
relative to the service root before passing them to Aider.

See `phase-2-generation.md` § "Path Rebasing" for the implementation.

### Lint Flags

| Flag | Purpose | Notes |
|------|---------|-------|
| `--lint-cmd` | Lint command | Aider appends edited filenames (cwd-relative) |
| `--auto-lint` | Run lint after each change | On by default, but explicit is clearer |

Aider's lint integration: after the model edits files, Aider runs
`<lint-cmd> <edited-file1> <edited-file2> ...`. If lint fails (non-zero exit),
Aider feeds the lint output back to the model and asks it to fix the errors.
This is Aider's internal retry loop — separate from the pipeline's retry loop.

**Note on auto-fix interaction:** The pipeline's `verify_task` node runs
auto-fix *after* Aider exits, as a cleanup step before the independent lint
check. Aider's internal `--auto-lint` loop runs the lint check command (not
the fix command) during the model's editing session. These are complementary:
Aider gives the model a chance to fix lint errors itself, and the pipeline's
auto-fix catches what the model couldn't resolve.

### Test Flags

| Flag | Purpose | Notes |
|------|---------|-------|
| `--test-cmd` | Test command | Aider runs it as-is (no filename appending) |
| `--auto-test` | Run tests after each change | Off by default — must opt in |

**Important**: Use `--auto-test` only for implementation tasks (where tests
should pass). Do NOT use `--auto-test` for test tasks — the tests are supposed
to fail (no implementation yet), and Aider would enter an infinite fix loop.

### Model String Format

For LM Studio, the model string format:
- `lm_studio/<model-name>` (auto-configures the base URL)

The `--openai-api-base` flag is included explicitly for reliability.

For cloud models (Anthropic, OpenAI), use the standard model string format
for that provider. The `api_base` and `api_key` come from the `MODELS` config,
with `api_key_env` values resolved at startup (see `config.py` §
`_resolve_api_keys`).

### Timeout and Generation Limits

Aider's `--timeout` flag only caps the HTTP connection setup phase. It does NOT
interrupt an in-progress streaming response. Once the model starts generating
(stream: true, which LM Studio uses by default), the timeout never fires.

The reliable fix is a server-side generation cap in LM Studio:
**Settings → "Max Tokens to Predict"** — set to a value like 8192.

Alternatively, configure `aider` with `stream: false` in `~/.aider.conf.yml`,
which makes `--timeout` effective again. But this loses streaming output.

### Reflection Exhaustion

When Aider can't fix lint or test errors after several internal retries, it
gives up — but still exits with code 0. The pipeline detects this by scanning
Aider's stdout for "reflections allowed, stopping" and marks the task as
"degraded" if tests still fail after independent verification.

## Prompt Composition

The `compose_prompt` node transforms a task's JSON into a markdown message
file. This is what the implementing model actually reads.

**File paths in the prompt** should use the rebased (cwd-relative) paths, not
the project-root-relative paths from tasks.json. This way the model writes file
content using the same paths Aider sees.

### Prompt Template

```markdown
# Task: <task.title>

## Project Context

<Brief context block — shared across all tasks. Includes:>
- What the project does (one sentence)
- Tech stack and language version
- Service root directory
- Import convention (e.g., "use `from plugins.*` not `from services.*`")
- Available conftest fixtures (if any exist from prior test tasks)

**Output constraint:** Respond with ONLY the file changes. Do not include
explanations, test commands, suggestions, or any conversational text.

## Objective

<task.description>

## Files to Create

<For each file in task.files, using REBASED paths:>
- **`<rebased_path>`** (<file.operation>): <file.description>

## Dependencies

<For each task in task.depends_on that created files this task imports from:>

### From `<rebased_path>` (created by <dep_task_id>)

```<language>
<Current content of the dependency file's public interface — class names,
method signatures, key constants. NOT the full file — just what this task
needs to know to write correct imports and call sites.>
```

<End of dependencies. If none: omit this section.>

## Reference Code

<For each ref in task.prototype_references:>
### From `prototypes/<feature>/<ref.file>`

<ref.what_to_reference>

```<language>
<actual code from the prototype file, extracted based on what_to_reference>
```

<End of prototype references. If none: omit this section.>

## Acceptance Criteria

<For each criterion in task.acceptance_criteria:>
- <criterion>

## Security Considerations

<For each sc in task.security_considerations:>
- **<sc.concern>**: <sc.mitigation>

<If none: omit this section entirely>
```

### Test-Task Prompt Additions

When composing prompts for `task_type: "test"` tasks, append this guidance
after the Acceptance Criteria section:

```markdown
## Test Writing Rules

- Write complete test functions with real assertions and proper mock setups.
- Do NOT use `raise NotImplementedError` in test function bodies — only
  production stubs raise NotImplementedError, never tests.
- Each test function must call the method under test and assert on the result.
- Use fixtures from conftest.py instead of writing your own mock wiring.
- Tests should FAIL when run (the implementation doesn't exist yet) but they
  must fail with the right error type (NotImplementedError from the stub or
  AssertionError from a real assertion) — not ImportError, TypeError, or
  setup errors.
```

This prevents the common failure mode where small models produce test files
that are nothing but `raise NotImplementedError` stubs, which pass the
pipeline's "expect failure" verification but provide no value as guardrails
for the implementation task.

### Dependency File Inlining

Cross-file interface coherence is one of the main code quality challenges
when each task is generated in isolation. The `compose_prompt` node mitigates
this by inlining the public interface of dependency files.

For each dependency listed in `task.depends_on`:

1. Find the task in `all_tasks` by ID
2. Get the files that dependency task created
3. If those files exist on disk (from a prior completed task), read them
4. Extract the public interface: class definitions, method signatures,
   module-level constants, type aliases — everything that downstream code
   needs to write correct imports and call sites
5. Include this in the prompt's Dependencies section

**What to inline:**
- Class name and inheritance (e.g., `class BloodGlucoseExtractor(BaseExtractor):`)
- Method signatures with type annotations
- Module-level constants referenced by callers
- Import paths (the exact `from X import Y` that the current task should use)

**What NOT to inline:**
- Method bodies (the model doesn't need implementation details)
- Private methods (prefixed with `_`)
- Test files (unless the current task is an implementation task that needs
  to know what tests expect)

**Size limit:** Keep inlined dependency context under ~500 tokens per
dependency. If a file is large, extract only the relevant interface elements.

### Retry Prompts

On retry (retry count > 0), augment the prompt with error context from the
previous attempt:

```markdown
## Previous Attempt (Failed)

The previous attempt failed with these errors:

### Lint Errors
```
<lint output from verify_task>
```

### Test Errors
```
<test output from verify_task>
```

Focus on fixing these specific issues in your response.
```

### Escalation Prompts

When escalating to a stronger model (model tier > 0), the prompt includes
all context from the weaker model's attempts:

```markdown
## Previous Model Attempts (Failed)

A weaker model attempted this task and exhausted its retries.
Here are the errors from its final attempt:

### Lint Errors
```
<lint output>
```

### Test Errors
```
<test output>
```

You are a stronger model. Fix these issues and produce correct code.
```

This gives the stronger model targeted context about what went wrong,
rather than having it start from scratch.

## Building the Aider Command

The `aider_bridge.py` module constructs and runs the Aider CLI command.

```python
import os
import subprocess

import config


def get_task_working_dir(task_id: str, all_tasks: list[dict]) -> str:
    if task_id in config.TASK_WORKING_DIRS:
        return config.TASK_WORKING_DIRS[task_id]

    task = _find_task(task_id, all_tasks)
    if task and task.get("phase") == "scaffold":
        return str(config.PROJECT_ROOT)

    return str(config.SERVICE_ROOT)


def rebase_path(file_path: str, working_dir: str) -> str:
    abs_file = os.path.join(str(config.PROJECT_ROOT), file_path)
    return os.path.relpath(abs_file, working_dir)


def build_command(
    task: dict,
    message_file_path: str,
    model_config: dict,
    lint_cmd: str | None,
    test_cmd: str | None,
    working_dir: str,
    extra_args: list[str],
) -> list[str]:
    """Build the aider CLI command with rebased file paths."""
    is_scaffold = task.get("phase") == "scaffold"

    cmd = [
        "aider",
        "--model", model_config["model"],
        "--openai-api-base", model_config["api_base"],
        "--openai-api-key", model_config["api_key"],
        "--message-file", message_file_path,
    ]

    for f in task.get("files", []):
        if is_scaffold:
            cmd.extend(["--file", f["path"]])
        else:
            rebased = rebase_path(f["path"], working_dir)
            cmd.extend(["--file", rebased])

    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    if test_cmd and task.get("task_type") == "implementation":
        cmd.extend(["--test-cmd", test_cmd, "--auto-test"])

    cmd.extend(extra_args)
    return cmd
```

### Running the Command

```python
def run_aider(cmd, working_dir, log_file):
    env = _clean_env()

    log_file.write(f"\n[aider] cwd={working_dir}\n")
    log_file.write(f"[aider] cmd={' '.join(cmd)}\n\n")

    try:
        result = subprocess.run(
            cmd, cwd=working_dir, capture_output=True,
            text=True, timeout=600, env=env,
        )
        log_file.write(result.stdout)
        if result.stderr:
            log_file.write("\n--- stderr ---\n")
            log_file.write(result.stderr)
        return result.returncode, result.stdout, result.stderr

    except subprocess.TimeoutExpired:
        msg = "Aider timed out after 600 seconds"
        log_file.write(f"\n[TIMEOUT] {msg}\n")
        return -1, "", msg
    except FileNotFoundError:
        msg = "aider command not found — install with: pip install aider-chat"
        log_file.write(f"\n[ERROR] {msg}\n")
        return -1, "", msg


def _clean_env():
    env = os.environ.copy()
    for var in ("VIRTUAL_ENV", "VIRTUAL_ENV_PROMPT"):
        env.pop(var, None)
    env.setdefault("OPENAI_API_KEY", "lm-studio")
    return env
```

### Verification Commands

```python
def run_verification(cmd, working_dir, timeout=120):
    env = _clean_env()
    try:
        result = subprocess.run(
            cmd, cwd=working_dir, capture_output=True,
            text=True, timeout=timeout, shell=True, env=env,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"Verification timed out after {timeout}s: {cmd}"
    except Exception as exc:
        return -1, "", str(exc)
```

### Message File Lifecycle

The composed prompt is written to a temp file that persists for the duration
of the task (including retries):

```python
def write_prompt(content, task_id):
    tmp_dir = config.PIPELINE_DIR / "tmp"
    tmp_dir.mkdir(exist_ok=True)
    path = tmp_dir / f"prompt-{task_id}.md"
    path.write_text(content, encoding="utf-8")
    return str(path)
```

Keep prompt files around after the run — they're useful for debugging. The
`tmp/` directory under the pipeline dir is gitignored by default.

### Reflection Exhaustion Detection

```python
def detect_reflection_exhaustion(aider_stdout):
    markers = [
        "reflections allowed, stopping",
        "Max reflections reached",
        "too many reflections",
    ]
    lower = aider_stdout.lower()
    return any(m.lower() in lower for m in markers)
```
