# Phase 3: Dry Run & Handoff — Detailed Guidance

## Syntax Check

Verify all generated Python files compile:

```bash
cd pipelines/<feature-name>
for f in $(find . -name "*.py"); do
    python -m py_compile "$f" && echo "  ✓ $f" || echo "  ✗ $f"
done
```

Fix any syntax errors before proceeding. Common issues:
- f-string formatting errors in generated config values
- Missing imports (especially pathlib, subprocess, json)
- Type hint syntax incompatible with the project's Python version

## Dry Run

Run the pipeline in dry-run mode:

```bash
cd <project-root>
python pipelines/<feature-name>/run.py --dry-run
```

Expected output:
1. Tasks loaded and validated (N tasks)
2. Execution order printed (topological sort)
3. Per-task summary: what would execute, which Aider arguments, lint/test commands
4. No Aider invocations

If the dry run fails, debug and fix the pipeline code. Common issues:
- `tasks.json` path incorrect in `config.py`
- Task schema import path not set up correctly
- Model endpoint format mismatch

## Dependency Installation

Before handing off, verify the requirements can be installed:

```bash
cd pipelines/<feature-name>
pip install -r requirements.txt
# or
uv pip install -r requirements.txt
```

If there are version conflicts with the project's existing dependencies, note
them. The pipeline's dependencies (langgraph, pydantic) are generally compatible
with most Python projects, but it's worth checking.

## Handoff Instructions

Present the user with clear run instructions. Tailor them to the detected
environment (uv vs pip, pytest vs jest, etc.).

### Template

```
## Pipeline Ready: <feature-name>

### Prerequisites

1. **LM Studio running** with <model-name> loaded
   - Endpoint: http://localhost:1234/v1
   - Verify: `curl -s http://localhost:1234/v1/models | python -m json.tool`

2. **Aider installed**
   - Install: `pip install aider-chat` or `uv tool install aider-chat`
   - Verify: `aider --version`

3. **Pipeline dependencies installed**
   ```bash
   cd pipelines/<feature-name>
   pip install -r requirements.txt
   ```

### Running

From the project root:

```bash
# Full run — all tasks in order
python pipelines/<feature-name>/run.py

# Resume from a specific task
python pipelines/<feature-name>/run.py --start task-05

# Dry run — see what would execute without invoking Aider
python pipelines/<feature-name>/run.py --dry-run

# Override model
python pipelines/<feature-name>/run.py --model "openai/different-model"

# Override retry limit
python pipelines/<feature-name>/run.py --max-retries 5
```

### Reading Results

- **Console output**: Real-time task progress (pass/fail/retry)
- **Log file**: `pipelines/<feature-name>/logs/run-<timestamp>.log`
- **Task results**: Printed as summary table at the end

### Troubleshooting

| Problem | Fix |
|---------|-----|
| "Connection refused" | Start LM Studio and load the model |
| "aider: command not found" | `pip install aider-chat` |
| Aider exits 0 but tests fail | Reflection exhaustion — pipeline catches this and retries or marks degraded |
| Task marked "failed" after retries | Check the log for error details; fix manually and resume with `--start` |
| Import errors in pipeline | Check Python version compatibility; run `pip install -r requirements.txt` |

### Configuration

All settings are in `pipelines/<feature-name>/config.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MODEL_TIERS[0]["model"]` | `<detected>` | LM Studio model string |
| `MODEL_TIERS[0]["api_base"]` | `http://localhost:1234/v1` | LM Studio endpoint |
| `MAX_RETRIES_PER_TASK` | `3` | Retries before marking task as failed |
| `DEFAULT_LINT_CMD` | `<detected>` | Lint command for Python files |
| `GLOBAL_TEST_CMD` | `<detected>` | Full test suite command |

### What happens next

The pipeline will:
1. Load tasks from `tasks/<feature-name>/tasks.json`
2. Execute each task in dependency order via Aider
3. Verify lint and tests after each task
4. Retry failed tasks up to the configured limit
5. Report final results with pass/fail/degraded status

Tasks that exhaust retries are marked as **failed** with an error summary.
You can fix them manually and resume the pipeline from the next task.
```

## Post-Handoff Notes

Remind the user:
- The pipeline modifies project source files (that's its job). Make sure
  the project is in a clean git state before running, so changes can be
  reviewed and reverted if needed.
- The prototype directory is read-only — the pipeline reads prototype files
  for reference but never modifies them.
- LM Studio's "Max Tokens to Predict" setting should be capped (e.g., 8192)
  to prevent infinite generation spirals. Aider's `--timeout` only caps
  connection setup, not streaming generation.
- The pipeline logs are append-only. Each run creates a new log file with
  a timestamp, so previous run logs are preserved.
