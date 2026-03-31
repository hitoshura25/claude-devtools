# Phase 3: Validation & Handoff — Detailed Guidance

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

## Precondition Validation

Instead of a dry-run (which diverges from real execution and creates false
confidence), validate the pipeline's configuration by checking preconditions
directly.

### Config consistency checks

1. **Task ID coverage:** Every task ID in `TASK_TEST_COMMANDS`,
   `TASK_LINT_OVERRIDES`, and `TASK_WORKING_DIRS` must exist in `tasks.json`.

2. **Path rebasing:** For each non-scaffold task, verify that its file paths
   start with the service root prefix. If a path doesn't start with the
   prefix, `rebase_path()` will produce `../` paths, which is probably wrong.

3. **Bootstrap config:** If `BOOTSTRAP_AFTER_TASK` is set, verify that task
   ID exists and is a scaffold-phase task. Verify the `BOOTSTRAP_COMMAND`
   is reasonable for the detected language (e.g., `uv sync` for Python
   with uv, `npm install` for Node).

4. **Working directory existence:** The project root must exist. The service
   root does NOT need to exist yet (the scaffold task creates it). But verify
   the project root path in `config.py` is correct.

### Schema import check

Verify the pipeline can import the task schema:

```bash
cd pipelines/<feature-name>
python -c "
import sys
sys.path.insert(0, str(config.TASKS_DIR))
from task_schema import TaskDecomposition
print('Schema import: OK')
"
```

### Dependency installation check

```bash
cd pipelines/<feature-name>
pip install -r requirements.txt
# or
uv pip install -r requirements.txt
```

## Handoff Instructions

Present the user with clear run instructions. Tailor them to the detected
environment.

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

From the pipeline directory:

```bash
# Full run — all tasks in order
python run.py

# Resume from a specific task
python run.py --start task-05

# Override model
python run.py --model "openai/different-model"

# Override retry limit
python run.py --max-retries 5
```

### What happens during the run

1. The pipeline loads tasks from `tasks/<feature-name>/tasks.json`
2. The scaffold task (task-01) runs from the project root — it creates the
   service directory structure and project config
3. **Automatic bootstrap**: After the scaffold task passes, the pipeline runs
   `<bootstrap-command>` to initialize the tooling environment (installs
   dependencies, makes lint/test tools available)
4. All remaining tasks run from the service root with lint and test verification
5. Failed tasks retry up to the configured limit, then are marked as failed
6. The pipeline continues past failures — downstream tasks that depend on a
   failed task are skipped

### Reading Results

- **Console output**: Real-time task progress (pass/fail/retry)
- **Log file**: `pipelines/<feature-name>/logs/run-<timestamp>.log`
- **Task results**: Printed as summary table at the end

### Troubleshooting

| Problem | Fix |
|---------|-----|
| "Connection refused" | Start LM Studio and load the model |
| "aider: command not found" | `pip install aider-chat` |
| Aider exits 0 but tests fail | Reflection exhaustion — pipeline retries or marks degraded |
| Task marked "failed" after retries | Check the log for error details; fix manually and resume with `--start` |
| "command not found" for lint/test | Bootstrap may have failed — check the bootstrap log output and run the bootstrap command manually |
| Import errors in pipeline | Check Python version compatibility; run `pip install -r requirements.txt` |

### Configuration

All settings are in `pipelines/<feature-name>/config.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MODEL_TIERS[0]["model"]` | `<detected>` | LM Studio model string |
| `MODEL_TIERS[0]["api_base"]` | `http://localhost:1234/v1` | LM Studio endpoint |
| `MAX_RETRIES_PER_TASK` | `3` | Retries before marking task as failed |
| `DEFAULT_LINT_CMD` | `<detected>` | Lint command (run from service root) |
| `GLOBAL_TEST_CMD` | `<detected>` | Full test suite command |
| `BOOTSTRAP_AFTER_TASK` | `<detected>` | Task that triggers tooling bootstrap |
| `BOOTSTRAP_COMMAND` | `<detected>` | Command to initialize tooling environment |
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
