# Executor Integration — Multi-Agent Dispatch and Prompt Composition

## Executor Types

The pipeline supports three executor types. Each is a coding agent CLI with
its own conventions for receiving prompts, editing files, and producing output.

| Type | CLI | Auth | File Editing | Prompt Input | Lint/Test Loop |
|------|-----|------|-------------|-------------|----------------|
| `aider` | `aider` | API key (LM Studio local, or cloud) | `--file` flags | `--message-file` | Built-in `--auto-lint`/`--auto-test` |
| `claude` | `claude` | Pro plan (OAuth, no API key) | Built-in tools (Read, Write, Bash) | `-p` flag or stdin | No built-in; pipeline handles it |
| `gemini` | `gemini` | Google account or `GEMINI_API_KEY` | Built-in tools (read_file, write_file, replace) | `-p` flag or stdin | No built-in; pipeline handles it |

The `agent_bridge.py` module dispatches to the right executor based on the
`type` field in the executor config.

## Executor Config Structure

Each executor is a named entry in `config.EXECUTORS`. The `type` field drives
dispatch; all other fields are type-specific.

### Aider Executors

Aider is model-agnostic — each Aider executor is named after the model it uses.

```python
"aider-local-qwen": {
    "type": "aider",
    "model": "lm_studio/qwen/qwen3-coder-30b",
    "api_base": "http://localhost:1234/v1",
    "api_key": "lm-studio",
},
"aider-gemini-flash": {
    "type": "aider",
    "model": "gemini/gemini-2.5-flash",
    "api_key_env": "GEMINI_API_KEY",
},
```

### Claude Executors

Claude CLI uses Pro plan auth — no API key needed. Different executors can
select different Claude model tiers.

```python
"claude": {
    "type": "claude",
    # Uses default model (currently Sonnet)
},
"claude-opus": {
    "type": "claude",
    "model": "opus",  # Passed as --model flag
},
```

### Gemini Executors

Gemini CLI uses Google account auth or `GEMINI_API_KEY`. Different executors
can select different Gemini model tiers.

```python
"gemini": {
    "type": "gemini",
    # Uses default model (currently gemini-2.5-pro)
},
"gemini-flash": {
    "type": "gemini",
    "model": "gemini-2.5-flash",  # Passed as -m flag
},
```

## Command Construction Per Executor Type

### Aider

Aider runs in scripting mode with explicit file paths.

```python
def _build_aider_command(executor_config, task, prompt_path, lint_cmd,
                         test_cmd, working_dir, extra_args):
    cmd = ["aider", "--model", executor_config["model"]]

    if "api_base" in executor_config:
        cmd.extend(["--openai-api-base", executor_config["api_base"]])
    if "api_key" in executor_config:
        cmd.extend(["--openai-api-key", executor_config["api_key"]])

    cmd.extend(["--message-file", prompt_path])

    # Files: rebased paths for non-scaffold tasks
    is_scaffold = task.get("phase") == "scaffold"
    for f in task.get("files", []):
        path = f["path"] if is_scaffold else rebase_path(f["path"], working_dir)
        cmd.extend(["--file", path])

    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    # --auto-test only for implementation tasks (test tasks should fail)
    if test_cmd and task.get("task_type") == "implementation":
        cmd.extend(["--test-cmd", test_cmd, "--auto-test"])

    cmd.extend(extra_args)
    return cmd
```

### Claude CLI

Claude CLI uses `-p` for non-interactive mode. It has built-in file editing
tools — no `--file` flags needed. Instead, the prompt tells Claude which
files to create/edit. The `--allowedTools` flag restricts what Claude can do.

```python
def _build_claude_command(executor_config, prompt_path, working_dir):
    cmd = ["claude", "-p"]

    if "model" in executor_config:
        cmd.extend(["--model", executor_config["model"]])

    # Allow file operations and shell commands
    cmd.extend(["--allowedTools", "Read,Write,Edit,Bash"])

    # Read prompt from file and pass as argument
    prompt_content = Path(prompt_path).read_text(encoding="utf-8")
    cmd.append(prompt_content)

    return cmd
```

**Important:** Claude CLI's `-p` mode accepts the prompt as a positional
argument or via stdin. For long prompts (common in our case), pipe via stdin
to avoid shell argument length limits:

```python
result = subprocess.run(
    ["claude", "-p", "--allowedTools", "Read,Write,Edit,Bash"]
    + (["--model", executor_config["model"]] if "model" in executor_config else []),
    input=prompt_content,
    cwd=working_dir,
    capture_output=True, text=True, timeout=600, env=env,
)
```

### Gemini CLI

Gemini CLI uses `-p` for non-interactive mode. Like Claude, it has built-in
file editing tools.

```python
def _build_gemini_command(executor_config, prompt_path, working_dir):
    cmd = ["gemini", "-p"]

    if "model" in executor_config:
        cmd.extend(["-m", executor_config["model"]])

    prompt_content = Path(prompt_path).read_text(encoding="utf-8")
    # Gemini CLI accepts prompt as positional arg or via stdin
    return cmd, prompt_content  # Pass prompt_content as stdin input
```

## Executor Dispatch

The `agent_bridge.py` module provides a unified interface for all executor types:

```python
def execute(executor_config, task, prompt_path, lint_cmd, test_cmd,
            working_dir, extra_args, log_file):
    """Dispatch to the right executor based on type."""
    executor_type = executor_config["type"]

    if executor_type == "aider":
        return _execute_aider(executor_config, task, prompt_path, lint_cmd,
                              test_cmd, working_dir, extra_args, log_file)
    elif executor_type == "claude":
        return _execute_claude(executor_config, task, prompt_path,
                               working_dir, log_file)
    elif executor_type == "gemini":
        return _execute_gemini(executor_config, task, prompt_path,
                               working_dir, log_file)
    else:
        raise ValueError(f"Unknown executor type: {executor_type}")
```

**Key difference:** For `claude` and `gemini` executors, lint/test commands are
NOT passed to the executor (they don't have `--auto-lint`/`--auto-test`). The
pipeline's `verify_task` node handles lint and test verification independently
after any executor exits. Aider executors optionally use `--auto-lint` and
`--auto-test` for their internal reflection loops, but `verify_task` always
runs independently as the authoritative check.

## Executor Resolution

The `resolve_executor` function determines which executor to use for a given
task based on its role and the current escalation tier:

```python
def resolve_executor(task: dict, current_tier: int) -> tuple[dict, str]:
    """Return (executor_config, role) for the given task and tier.

    Role is determined from the task's type and phase:
    - scaffold/infrastructure phase → "scaffold" role
    - test type → "test" role
    - implementation type → "implementation" role
    """
    task_type = task.get("task_type", "implementation")
    phase = task.get("phase", "")

    if phase in ("scaffold", "infrastructure"):
        role = "scaffold"
    else:
        role = task_type  # "test" or "implementation"

    executors_for_role = config.EXECUTOR_ROLES.get(
        role, config.EXECUTOR_ROLES["implementation"]
    )
    tier_idx = min(current_tier, len(executors_for_role) - 1)
    executor_name = executors_for_role[tier_idx]
    executor_config = config.EXECUTORS[executor_name]

    return executor_config, role
```

## Prompt Composition

The `compose_prompt` node produces a markdown prompt that works with any
executor type. The prompt content is identical regardless of executor — the
only difference is how it's delivered (Aider reads from `--message-file`,
Claude and Gemini receive it via stdin with `-p`).

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

<For each dependency task that created files this task imports from:>

### From `<rebased_path>` (created by <dep_task_id>)

```<language>
<Current content of the dependency file's public interface>
```

## Reference Code

<For each ref in task.prototype_references:>
### From `prototypes/<feature>/<ref.file>`

```<language>
<actual code from the prototype file>
```

## Acceptance Criteria

<For each criterion in task.acceptance_criteria:>
- <criterion>

## Security Considerations

<For each sc in task.security_considerations, if any:>
- **<sc.concern>**: <sc.mitigation>
```

### Test-Task Prompt Additions

For `task_type: "test"` tasks, append after Acceptance Criteria:

```markdown
## Test Writing Rules

- Write complete test functions with real assertions and proper mock setups.
- Do NOT use `raise NotImplementedError` in test function bodies — only
  production stubs raise NotImplementedError, never tests.
- Each test function must call the method under test and assert on the result.
- Use fixtures from conftest.py instead of writing your own mock wiring.
- Tests should FAIL when run (the implementation doesn't exist yet) but they
  must fail with the right error type (NotImplementedError from the stub or
  AssertionError) — not ImportError, TypeError, or setup errors.
```

### Dependency File Inlining

For each dependency in `task.depends_on`:
1. Find the dependency task and its created files
2. If those files exist on disk, read the public interface
3. Include class names, method signatures, import paths in the Dependencies section

**What to inline:** Class name, inheritance, method signatures with type annotations,
module-level constants, import paths.

**What NOT to inline:** Method bodies, private methods, test files.

**Size limit:** ~500 tokens per dependency.

### Retry Prompts

On retry, augment with error context from the previous attempt:

```markdown
## Previous Attempt (Failed)

### Lint Errors
```
<lint output>
```

### Test Errors
```
<test output>
```

Focus on fixing these specific issues.
```

### Escalation Prompts

When escalating to a stronger executor:

```markdown
## Previous Executor Attempts (Failed)

A previous coding agent attempted this task and exhausted its retries.
Errors from its final attempt:

### Lint Errors
```
<lint output>
```

### Test Errors
```
<test output>
```

Fix these issues and produce correct code.
```

## Subprocess Execution

All executors run as subprocesses with a clean environment:

```python
def _clean_env():
    env = os.environ.copy()
    # Strip pipeline's venv so service tooling resolves correctly
    for var in ("VIRTUAL_ENV", "VIRTUAL_ENV_PROMPT"):
        env.pop(var, None)
    env.setdefault("OPENAI_API_KEY", "lm-studio")
    return env
```

Timeout: 600 seconds (configurable). Applies to all executor types.

### Reflection Exhaustion Detection

Only relevant for Aider executors. Claude and Gemini CLIs don't have an
internal reflection loop — they either complete the task or don't.

```python
def detect_reflection_exhaustion(executor_type, stdout):
    if executor_type != "aider":
        return False
    markers = ["reflections allowed, stopping", "Max reflections reached"]
    lower = stdout.lower()
    return any(m.lower() in lower for m in markers)
```

## Verification Commands

Independent of executor type — always runs after the executor exits:

```python
def run_verification(cmd, working_dir, timeout=120):
    env = _clean_env()
    result = subprocess.run(
        cmd, cwd=working_dir, capture_output=True,
        text=True, timeout=timeout, shell=True, env=env,
    )
    return result.returncode, result.stdout, result.stderr
```

## Startup Validation

For each executor that appears in any `EXECUTOR_ROLES` chain:

| Executor type | Validation |
|--------------|------------|
| `aider` | `which aider`, check `api_key_env` if present, check `api_base` reachability for local models |
| `claude` | `which claude`, verify auth works (`claude -p "hello" --max-turns 1`) |
| `gemini` | `which gemini`, verify auth works (`gemini -p "hello" --output-format json`) |

Fail fast at pipeline startup with a clear error message if any active
executor is not available.
