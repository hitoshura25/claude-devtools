# Test & Lint Tooling Reference

## How Auto-Validation Works

From the [aider docs](https://aider.chat/docs/usage/lint-test.html) and [options reference](https://aider.chat/docs/config/options.html):

**Linting:**
- `--lint-cmd CMD` — defines the lint command. Per aider docs: "The lint command should accept the filenames of the files to lint." Aider appends the edited filenames as arguments.
- `--auto-lint` — runs lint after each edit. **Defaults to TRUE** — we pass it explicitly for clarity.

**Testing:**
- `--test-cmd CMD` — defines the test command. Per aider docs: "Aider will run the test command without any arguments." No filenames appended.
- `--auto-test` — runs tests after each edit. **Defaults to FALSE** — we pass it explicitly to opt in.

When aider can't fix a lint/test failure after several attempts, it exits non-zero. The runner halts and tells the user which task failed and how to resume.

### Critical: How aider invokes lint commands

Since aider appends edited filenames to the lint command, paths must make sense from aider's working directory (project root). For example, if the lint command is `cd services/foo && lint .` and aider edits `services/foo/bar.ts`, aider runs:

```bash
cd services/foo && lint . services/foo/bar.ts
```

This breaks because after `cd services/foo`, the path `services/foo/bar.ts` doesn't exist from that working directory.

The lint command must work from the project root. For some linters (particularly those that don't filter by file extension), a wrapper script is needed — see the stack file for your language.

Test commands don't have this problem — aider runs them exactly as given, no filenames appended.

### The lint wrapper problem

Some linters fail when passed non-source files (config files, Dockerfiles, etc.) that aider happens to have edited. Check whether your linter handles this gracefully:
- If the linter only processes files matching its own extensions → no wrapper needed
- If the linter fails or warns on non-source files passed explicitly → use a wrapper script

See `stacks/<language>-<framework>.md` for whether a wrapper is needed and how to set one up.

---

## Discovering the Right Setup

Every project manages dependencies and tooling differently. Investigate the project first, then set up tooling consistent with what's already there.

### Step 1: Investigate the Project

Before installing anything, check what already exists:

**Package manager indicators:**
- `pyproject.toml` with `[tool.uv]` or `uv.lock` → Python, **uv**
- `pyproject.toml` with `[tool.poetry]` → Python, **poetry**
- `requirements.txt` only → Python, plain **pip**
- `package.json` → Node.js — check for `npm`/`yarn`/`pnpm` lockfiles
- `build.gradle` / `build.gradle.kts` → Kotlin/Java, **Gradle**
- `Cargo.toml` → Rust, **cargo**
- `go.mod` → Go, **go modules**

**Monorepo indicators:**
- Multiple per-service config files in subdirectories → per-service environments
- `services/`, `packages/`, or `apps/` directory structure → multi-service layout

**Existing tooling:**
- Linter config files (`.eslintrc`, `pyproject.toml [tool.ruff]`, `.golangci.yml`) → already configured
- Test config sections → already configured

### Step 2: Determine the Scope

For a monorepo, tooling setup belongs to the specific service being implemented.

| Project Structure | Environment Scope | Config Location |
|---|---|---|
| Single project | Project root | root config file |
| Monorepo, per-service | Service directory | `services/my-service/` config |
| Monorepo, shared workspace | Project root with workspaces | root config with workspace members |

### Step 3: Install All Dependencies

Install the project's actual dependencies *in addition to* lint and test tools. Tests will fail with import/module errors if only lint and test tools are installed but the project's libraries are missing.

Use whatever package manager the project uses. See `stacks/<language>-<framework>.md` for specific install commands.

### Step 4: Create Minimal Test Infrastructure

1. Config file with lint and test sections
2. Test directory and test entry point
3. Smoke test that proves the toolchain works
4. Run and verify both commands exit 0

### Step 5: Set Up the Lint Command

Determine whether your linter needs a wrapper script (see § "The lint wrapper problem" above and the stack file). Make the lint command executable and test it from the project root before recording it in the manifest.

### Step 6: Record Commands for the Manifest

```json
{
  "tooling": {
    "lint_cmd": "<lint command or wrapper path>",
    "test_cmd": "<test command — cd is safe here>",
    "language": "<python|typescript|kotlin|rust|go>",
    "framework": "<pytest|jest|junit|cargo-test|go-test>",
    "linter": "<ruff|eslint|ktlint|clippy|golangci-lint>"
  }
}
```

### If Setup Already Exists

If the project already has working tooling, don't reinstall — verify the commands work from the project root and record them.

---

## Language-Specific Stack Files

After identifying the project's language and test framework, read the appropriate stack file for:
- Exact install commands and package manager patterns
- Whether a lint wrapper is needed and how to configure it
- How to mock frameworks not installed in the dev environment
- Fixture patterns for external service clients
- Mutation testing tool and commands
- Stub design patterns for the language

| Language | Framework | Stack file |
|----------|-----------|------------|
| Python | pytest | `stacks/python-pytest.md` |
| TypeScript / JavaScript | Jest | `stacks/typescript-jest.md` |
| Kotlin / Java | JUnit (Gradle) | `stacks/kotlin-junit.md` |
| Rust | cargo test | see mutation table below, no stack file yet |
| Go | go test | see mutation table below, no stack file yet |

For languages without a stack file, use the general setup steps above and the mutation testing table below.

---

## Creating External Dependency Mock Fixtures

Small models consistently fail at mocking external service clients. The pattern is always the same: the model writes a test, gets the mock wiring subtly wrong (fluent chain doesn't return the right mock, buffer write never happens, connection lifecycle doesn't match), then exhausts all its reflections trying to debug mock plumbing instead of writing business logic.

The fix: Claude Code creates reusable fixtures during scaffold setup. These fixtures handle the tricky mock internals once, correctly. The small model's tests use them by name and only configure return values.

### When to Create a Fixture

Create a fixture for any external dependency that meets these criteria:
- Has a fluent or chained API (e.g., `service.files().list().execute()`)
- Requires simulating I/O (downloads writing to buffers, uploads capturing bytes)
- Has a connect/use/close lifecycle (database connections, message brokers)
- **Has a positional argument trap** — a call where argument order is non-obvious, easy to swap, and wrong usage fails at runtime rather than definition time
- Is used by multiple tasks in the plan

Common candidates: cloud storage clients, message broker clients, database drivers, HTTP clients with session management, serialization libraries with non-obvious call signatures.

#### Positional Argument Traps

Some library functions have positional arguments whose order cannot be inferred from the function name or argument values. Small models consistently get these wrong. The error appears at runtime, not at the point of writing the call, and the model exhausts its reflections guessing at fixes.

**Signal:** A function call where:
1. Two or more positional arguments have the same or similar types
2. The argument names don't appear at the call site
3. Swapping the arguments produces a plausible-looking but incorrect call

**Fix:** Mock the call in the fixture so the model never writes it directly. The fixture captures what was passed so tests can assert on the arguments. See the stack file for a language-specific example.

**Other examples of the pattern** (not exhaustive):
- Serialization libraries that take `(output, schema, data)` or `(output, data, schema)` depending on version
- Some SQL driver `execute(query, params)` variants where param binding style differs by driver
- `struct.pack(fmt, *values)` style calls where format string and values are easily swapped

### How to Create Them

Each fixture should:
1. Patch at the correct import boundary (where the implementation imports from)
2. Wire the full mock chain so the model doesn't need to understand library internals
3. Expose simple attributes for test customization (set return values, check call args)
4. Handle I/O simulation correctly (writing to buffers, capturing upload bytes)
5. Clean up patches after the test

See `stacks/<language>-<framework>.md` for concrete fixture examples in your language.

### Listing Fixtures in the Project Context

After creating fixtures, list them in the project context block embedded in every task doc:

```
Available test fixtures (use these instead of writing your own mocks):
- `mock_storage_client` — pre-wired cloud storage mock with upload capture
- `mock_queue_client` — pre-wired message broker mock with channel/publish
```

The names and one-line descriptions are enough — the model adds the fixture name to its test function parameters and the framework injects it.

### Mocking Framework Modules

When the target framework (e.g. a job scheduler, web framework, or ORM) is not installed in the dev environment, stub every anticipated import path before collection time. The critical rule applies to all languages:

**For any import path `a.b.c` the implementation will use, every prefix must be registered separately.** If only `a.b` is registered as a stub, importing `a.b.c` will fail because `a.b` is seen as a concrete object, not a package.

**Verification step**: After writing the test setup, run a bare import of the implementation module with only the test infrastructure loaded — before running any actual tests — and confirm no import errors surface.

During plan writing, scan the implementation spec for every deep import path and cross-check each against the mock list. A task doc that tells the model "X is mocked in tests" when the test setup doesn't actually register X is a broken promise the small model cannot fix.

See `stacks/<language>-<framework>.md` for the language-specific mechanism (Python `sys.modules`, Jest `moduleNameMapper`, etc.).

### Verifying Fixtures

After creating fixtures, write a minimal smoke test per fixture that confirms the fixture is reachable and its key attributes exist. Run the test suite and verify these pass before generating task docs.

**For persistence classes** (any store backed by a file, database, or in-memory structure): when writing the mutation-gate stub, deliberately omit schema/table initialization from the constructor. If tests pass against this stub, they won't catch an implementation that forgets to initialize schema before use. You want the tests to fail against the empty stub on the very first method call that requires the schema.

---

## Mutation Testing

Mutation testing verifies that tests actually catch bugs. A mutation tool makes small, deliberate code changes ("mutants") and re-runs the tests. If a test passes with a mutated stub, that test wouldn't catch that class of bug in the real implementation.

Run this during Step 3b before embedding tests in task docs. Target: ≥80% mutation score.

**This step uses a stub implementation — not the final code.** Mutations are applied to the stub so you can detect whether tests are sensitive to logic changes.

### Tool by Language

| Language | Tool | Install | Run |
|----------|------|---------|-----|
| Python | mutmut | `pip install mutmut` | `mutmut run --paths-to-mutate <file>` |
| TypeScript/JS | Stryker | `npm i -D @stryker-mutator/core` | `npx stryker run` |
| Kotlin/Java | Pitest | Gradle plugin `info.solidsoft.pitest` | `./gradlew pitest` |
| Rust | cargo-mutants | `cargo install cargo-mutants` | `cargo mutants --file <file>` |
| Go | go-mutesting | `go install zimmski/go-mutesting` | `go-mutesting ./pkg/...` |

See `stacks/<language>-<framework>.md` for detailed configuration and interpreting results.

### When Mutation Testing Isn't Available

If no mutation tool is practical (shell scripts, SQL, config-heavy projects), apply the anti-patterns checklist from `writing-guide.md` § "Anti-Patterns to Avoid" manually as a code review step. Document that mutation testing was skipped in the manifest:

```json
"mutation_gate": "skipped",
"mutation_gate_reason": "shell script — no mutation tool available"
```
