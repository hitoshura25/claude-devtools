# Aider Integration — Scripting Mode and Prompt Composition

## Aider CLI Reference for Pipeline Use

The pipeline invokes Aider in scripting mode — no interactive session, no chat.
Each task is a single `--message-file` invocation that exits after processing.

### Core Flags

| Flag | Purpose | Value |
|------|---------|-------|
| `--model` | LLM to use | `openai/<model-name>` or `lm_studio/<model-name>` |
| `--openai-api-base` | LM Studio endpoint | `http://localhost:1234/v1` |
| `--openai-api-key` | API key (LM Studio doesn't validate) | `lm-studio` |
| `--message-file` | Task prompt file | `/tmp/pipeline-task-<id>.md` |
| `--file` | Files Aider can edit | One per file in the task's `files` list |
| `--yes-always` | Skip all confirmations | (flag only) |
| `--no-git` | Pipeline manages git, not Aider | (flag only) |
| `--no-check-update` | Don't check for Aider updates | (flag only) |
| `--no-show-model-warnings` | Suppress model compatibility warnings | (flag only) |

### Lint Flags

| Flag | Purpose | Notes |
|------|---------|-------|
| `--lint-cmd` | Lint command | Aider appends edited filenames |
| `--auto-lint` | Run lint after each change | On by default, but explicit is clearer |

Aider's lint integration: after the model edits files, Aider runs
`<lint-cmd> <edited-file1> <edited-file2> ...`. If lint fails (non-zero exit),
Aider feeds the lint output back to the model and asks it to fix the errors.
This is Aider's internal retry loop — separate from the pipeline's retry loop.

### Test Flags

| Flag | Purpose | Notes |
|------|---------|-------|
| `--test-cmd` | Test command | Aider runs it as-is (no filename appending) |
| `--auto-test` | Run tests after each change | Off by default — must opt in |

Aider's test integration: after editing (and passing lint), Aider runs the
test command. If tests fail, Aider feeds the output back to the model for
another attempt. This is Aider's internal reflection loop.

**Important**: Use `--auto-test` only for implementation tasks (where tests
should pass). Do NOT use `--auto-test` for test tasks — the tests are supposed
to fail (no implementation yet), and Aider would enter an infinite fix loop.

### Model String Format

For LM Studio, the model string depends on the Aider version:

- **Older format**: `openai/<model-name>` with `--openai-api-base`
- **Newer format**: `lm_studio/<model-name>` (auto-configures the base URL)

The `run-tasks-template.sh` from agent-ready-plans uses `lm_studio/qwen/qwen3-coder-30b`.
Use this format as the default. The `--openai-api-base` flag is redundant when
using the `lm_studio/` prefix but doesn't hurt to include for compatibility.

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
file. This is what the implementing model (Qwen/Codestral) actually reads.

### Prompt Template

```markdown
# Task: <task.title>

## Objective

<task.description>

## Files to Create

<For each file in task.files:>
- **`<file.path>`** (<file.operation>): <file.description>

## Reference Code

<For each ref in task.prototype_references:>
### From `prototypes/<feature>/<ref.file>`

<ref.what_to_reference>

```<language>
<actual code from the prototype file, extracted based on what_to_reference>
```

<End of prototype references. If none:>
No prototype references for this task.

## Acceptance Criteria

<For each criterion in task.acceptance_criteria:>
- <criterion>

## Security Considerations

<For each sc in task.security_considerations:>
- **<sc.concern>**: <sc.mitigation>

<If none: omit this section entirely>

## Output Constraint

Respond with ONLY the file changes. Do not include explanations, test commands,
suggestions, or any conversational text.
```

### Inlining Prototype References

The key distinction from the agent-ready-plans approach: prototype references
are file pointers in the task JSON, not pre-inlined content. The `compose_prompt`
node must resolve them at prompt generation time.

For each `PrototypeReference` in the task:

1. Read the referenced file from `prototypes/<feature>/<ref.file>`
2. If `what_to_reference` mentions specific lines (e.g., "lines 23-31"),
   extract that range
3. If `what_to_reference` is descriptive (e.g., "the API response parsing
   logic"), include the full file but prefix it with the description as
   context for the model
4. If the file doesn't exist, log a warning and skip it — don't crash the
   pipeline

### Prompt Size Management

Local models have limited context windows (~32k tokens for Qwen 3 Coder 30B).
The composed prompt must fit within this budget along with the model's response.

Budget estimate:
- Task description + files + criteria: ~500-1500 tokens
- Each prototype reference: varies (could be 100-2000 tokens per file)
- Output constraint: ~50 tokens
- Reserve for model response: ~4000-8000 tokens

If the total prompt exceeds ~20k tokens, truncate prototype references
(include only the most relevant section, not the full file). Log a warning
when truncation happens.

### Retry Prompts

On retry (retry count > 0), the compose_prompt node should augment the prompt
with error context from the previous attempt:

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

This gives the model targeted feedback rather than having it start from scratch.
Store the error output in the pipeline state so compose_prompt can access it
on retry.

## Building the Aider Command

The `aider_bridge.py` module constructs the full command. Here's the logic:

```python
def build_command(
    task: dict,
    message_file_path: str,
    model_tier: dict,      # From config.MODEL_TIERS
    lint_cmd: str | None,  # Effective lint for this task
    test_cmd: str | None,  # Effective test for this task
    extra_args: list[str], # From config.AIDER_EXTRA_ARGS
) -> list[str]:
    cmd = [
        "aider",
        "--model", model_tier["model"],
        "--openai-api-base", model_tier["api_base"],
        "--openai-api-key", model_tier["api_key"],
        "--message-file", message_file_path,
    ]

    # Files Aider can edit
    for f in task.get("files", []):
        cmd.extend(["--file", f["path"]])

    # Lint (always, for both test and implementation tasks)
    if lint_cmd:
        cmd.extend(["--lint-cmd", lint_cmd, "--auto-lint"])

    # Test (implementation tasks only)
    if test_cmd and task.get("task_type") == "implementation":
        cmd.extend(["--test-cmd", test_cmd, "--auto-test"])

    cmd.extend(extra_args)
    return cmd
```

### Running the Command

```python
import subprocess
import os

def run_aider(cmd: list[str], working_dir: str, log_file) -> tuple[int, str, str]:
    """Run Aider and capture output."""
    env = os.environ.copy()
    # LM Studio doesn't need a real key, but Aider's OpenAI client requires one
    env.setdefault("OPENAI_API_KEY", "lm-studio")

    try:
        result = subprocess.run(
            cmd,
            cwd=working_dir,
            capture_output=True,
            text=True,
            timeout=600,
            env=env,
        )
        # Log full output
        log_file.write(result.stdout)
        log_file.write(result.stderr)

        return result.returncode, result.stdout, result.stderr

    except subprocess.TimeoutExpired:
        return -1, "", "Aider timed out after 600 seconds"
    except FileNotFoundError:
        return -1, "", "aider command not found"
```

### Message File Lifecycle

The composed prompt is written to a temp file that persists for the duration
of the task (including retries):

```python
import tempfile

def write_prompt(content: str, task_id: str, pipeline_dir: str) -> str:
    """Write prompt to a file in the pipeline's tmp directory."""
    tmp_dir = os.path.join(pipeline_dir, "tmp")
    os.makedirs(tmp_dir, exist_ok=True)
    path = os.path.join(tmp_dir, f"prompt-{task_id}.md")
    with open(path, "w") as f:
        f.write(content)
    return path
```

Keep prompt files around after the run — they're useful for debugging. The
`tmp/` directory under the pipeline dir is gitignored by default.
