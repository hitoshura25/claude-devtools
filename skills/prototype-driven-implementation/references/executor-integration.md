# Executor Integration — Multi-Agent Dispatch and Prompt Composition

## Executor Types

The pipeline supports three executor types. Each is a coding agent CLI with
its own conventions for receiving prompts, editing files, and producing output.

| Type | CLI | Auth | File Editing | Prompt Input | Lint/Test Loop |
|------|-----|------|-------------|-------------|----------------|
| `aider` | `aider` | API key (LM Studio local, or cloud) | `--file` flags | `--message-file` | Built-in `--auto-lint`/`--auto-test` |
| `claude` | `claude` | Pro plan (OAuth, no API key) | Built-in tools | `-p` flag with stdin | No built-in; pipeline handles it |
| `gemini` | `gemini` | Google account or `GEMINI_API_KEY` | Built-in tools | `-p` flag with stdin | No built-in; pipeline handles it |

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

### Claude and Gemini Executors

Claude and Gemini executors store their invocation patterns as determined
by Phase 1 research. The `invocation` field captures the verified command
flags so `agent_bridge.py` can construct the correct subprocess call.

```python
"claude": {
    "type": "claude",
    "invocation": {
        # These fields are populated from Phase 1 research
        # of the CLI's official documentation.
        "non_interactive_flag": "<researched>",
        "tool_permissions_flags": ["<researched>"],
        "model_flag": "<researched>",
        "turn_limit_flag": "<researched>",
        "prompt_delivery": "stdin",  # or "argument"
    },
},
"claude-opus": {
    "type": "claude",
    "model": "opus",
    "invocation": { ... },  # Same structure, different model
},
"gemini": {
    "type": "gemini",
    "invocation": { ... },
},
"gemini-flash": {
    "type": "gemini",
    "model": "gemini-2.5-flash",
    "invocation": { ... },
},
```

The `invocation` block comes from Phase 1's research step (see
`phase-1-analysis.md` § "Step 2: Research Non-Interactive Invocation Patterns").
This ensures the pipeline uses the current, verified CLI flags rather than
potentially stale hardcoded patterns.

## Command Construction Per Executor Type

### Aider

Aider's interface is well-established and stable. Its command construction
is hardcoded:

```python
def _build_aider_command(executor_config, task, prompt_path, lint_cmd,
                         test_cmd, working_dir):
    cmd = ["aider", "--model", executor_config["model"]]

    if "api_base" in executor_config:
        cmd.extend(["--openai-api-base", executor_config["api_base"]])
    if "api_key" in executor_config:
        cmd.extend(["--openai-api-key", executor_config["api_key"]])

    cmd.extend(["--message-file", prompt_path])

    is_scaffold = task.get("phase") == "scaffold"
    for f in task.get("files", []):
        path = f["path"] if is_scaffold else rebase_path(f["path"], working_dir)
        cmd.extend(["--file", path])

    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    if test_cmd and task.get("task_type") == "implementation":
        cmd.extend(["--test-cmd", test_cmd, "--auto-test"])

    cmd.extend(config.AIDER_EXTRA_ARGS)
    return cmd
```

### Claude and Gemini CLIs

Command construction for Claude and Gemini executors is **generated from the
invocation patterns discovered during Phase 1 research**. The generated
`agent_bridge.py` builds commands using the researched flags stored in each
executor's `invocation` config.

The general pattern for both:

```python
def _execute_cli_executor(executor_config, prompt_path, working_dir, log_file):
    """Generic CLI executor for claude/gemini-type executors.

    Builds the command from the researched invocation config, pipes the
    prompt via stdin, and captures output.
    """
    invocation = executor_config["invocation"]
    prompt_content = Path(prompt_path).read_text(encoding="utf-8")

    # Build command from researched flags
    cmd = [executor_config["type"]]  # "claude" or "gemini"
    cmd.append(invocation["non_interactive_flag"])
    cmd.extend(invocation["tool_permissions_flags"])

    if "model" in executor_config and invocation.get("model_flag"):
        cmd.extend([invocation["model_flag"], executor_config["model"]])

    if invocation.get("turn_limit_flag"):
        cmd.extend([invocation["turn_limit_flag"], "30"])

    env = _clean_env()

    # Prompt is delivered via stdin to avoid shell argument length limits
    result = subprocess.run(
        cmd,
        input=prompt_content,
        cwd=working_dir,
        capture_output=True, text=True,
        timeout=config.EXECUTOR_TIMEOUT,
        env=env,
    )
    return result.returncode, result.stdout, result.stderr
```

**Why not hardcode the flags here?** CLI tools update their flag syntax,
permission models, and headless-mode behavior across versions. The Phase 1
research step reads the current official documentation and verifies the
pattern with a test prompt before the pipeline is generated. This means the
generated `agent_bridge.py` always reflects the CLI's actual current interface.

## Executor Dispatch

The `agent_bridge.py` module provides a unified interface:

```python
def execute(executor_config, task, prompt_path, lint_cmd, test_cmd,
            working_dir, log_file):
    executor_type = executor_config["type"]

    if executor_type == "aider":
        return _execute_aider(executor_config, task, prompt_path, lint_cmd,
                              test_cmd, working_dir, log_file)
    elif executor_type in ("claude", "gemini"):
        return _execute_cli_executor(executor_config, prompt_path,
                                     working_dir, log_file)
    else:
        raise ValueError(f"Unknown executor type: {executor_type}")
```

**Key difference:** For `claude` and `gemini` executors, lint/test commands are
NOT passed to the executor. The pipeline's `verify_task` node handles lint and
test verification independently after any executor exits. Aider executors
optionally use `--auto-lint` and `--auto-test` for their internal reflection
loops, but `verify_task` always runs independently as the authoritative check.

## Executor Resolution

```python
def resolve_executor(task: dict, current_tier: int) -> tuple[dict, str]:
    task_type = task.get("task_type", "implementation")
    phase = task.get("phase", "")

    if phase in ("scaffold", "infrastructure"):
        role = "scaffold"
    else:
        role = task_type

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
Claude and Gemini receive it via stdin).

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

**What to inline:** Class name, inheritance, method signatures with type
annotations, module-level constants, import paths.

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
