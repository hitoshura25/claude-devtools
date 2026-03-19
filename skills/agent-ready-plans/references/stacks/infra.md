# Infrastructure Stack Reference

Read this file when:
- Any task in the plan creates a `Dockerfile`, `*.compose.yml`, `*.compose.yaml`,
  Kubernetes YAML, or Terraform files
- Setting up per-task tooling for infrastructure tasks (SKILL.md Step 2)
- Writing smoke tests for container tasks (SKILL.md Step 3b)

---

## Detecting Infrastructure Tasks

Scan each task's `files_created` list for these patterns. When you find them,
that task needs infra tooling instead of (or in addition to) the project's
primary language tooling.

| File pattern | Task type | Linter | Test |
|---|---|---|---|
| `Dockerfile`, `Dockerfile.*`, `*.dockerfile` | Container image | hadolint | Docker smoke test |
| `*compose*.yml`, `*compose*.yaml` | Service orchestration | `docker compose config` | Docker smoke test |
| `*.tf`, `*.tfvars` | Terraform | `terraform validate` | (deferred — complex, out of scope for now) |
| `*.yaml` in `k8s/`, `kubernetes/`, `helm-charts/` | Kubernetes | `kubectl apply --dry-run=client` | (deferred — out of scope for now) |

When a task creates **both** Python files and infrastructure files, use the
`infra-lint-wrapper-template.sh` (which handles all types) as the task-level
`lint_cmd` override rather than the ruff-only wrapper.

---

## Sequencing Rule

**Infrastructure tasks must be sequenced after all service tasks they package.**

The runner executes tasks sequentially. Building a Docker image of service code
that hasn't been implemented yet is meaningless. Set `depends_on` to include
every task whose output ends up inside the container. This is usually the wiring
task plus all component tasks — which in practice means the Docker task is always
near the end of the plan, after components, wiring, and Docker. The integration
test task then depends on the Docker task.

This sequencing has a practical benefit: by the time the smoke test runs, all
unit tests have already passed. If the smoke test fails, the problem is almost
certainly in the Dockerfile or compose configuration, not in the underlying code.

---

## Tooling Setup (Step 3)

### Install hadolint

```bash
# macOS
brew install hadolint

# Linux (apt)
apt-get install -y hadolint

# Linux (binary, if apt not available)
curl -L \
  https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
  -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint

# Verify
hadolint --version
```

Verify `docker compose` is available (not `docker-compose`):
```bash
docker compose version
```

### Set up the lint wrapper

Copy the infra lint wrapper template into the tasks folder:

```bash
cp scripts/infra-lint-wrapper-template.sh docs/plans/my-tasks/infra-lint.sh
chmod +x docs/plans/my-tasks/infra-lint.sh
```

If the project has Python files that might appear alongside infra files in the
same aider edit, set `RUFF_BIN` in the wrapper. Otherwise leave it empty.

Test it from the project root before recording in the manifest:
```bash
./docs/plans/my-tasks/infra-lint.sh \
  services/my-service/Dockerfile \
  services/my-service/deployment/service.compose.yml
```

---

## Dockerfile and Test Compose as Scaffold (Step 3)

The Dockerfile and the test compose file are both scaffold — Claude Code writes
them, validates them, and keeps them on disk. The small model only creates the
production compose file.

Small models cannot debug infrastructure authoring errors — wrong image tags,
fabricated version numbers, hadolint violations, or missing environment variables
all consume the model's entire reflection budget on problems it cannot fix. By
validating the Dockerfile and test compose during scaffold, these errors are
caught at authoring time (when they're cheap to fix) rather than at run time
(when they're fatal). Both follow the same principle as test files: Claude Code
does the verification work, and the validated artifact stays on disk as the
single source of truth.

### Step 1: Verify the tag exists

For every `FROM` line in the planned Dockerfile, run:

```bash
docker manifest inspect <image>:<tag>
```

If `docker manifest inspect` fails, the tag does not exist. Search for the
correct tag:

```bash
# List available tags (Docker Hub images)
# Use web search or Docker Hub API — e.g.:
curl -s "https://hub.docker.com/v2/repositories/<namespace>/<image>/tags/?page_size=50&name=<partial>" \
  | python3 -c "import sys,json; [print(t['name']) for t in json.load(sys.stdin)['results']]"
```

For official Docker Hub images (e.g. `python`, `node`), replace `<namespace>`
with `library`. For community images (e.g. `apache/airflow`), use the org name.

Pick the tag that matches the project's requirements (language version, variant)
and re-verify with `docker manifest inspect`. Do not proceed until the tag
resolves.

### Step 2: Write a draft Dockerfile, build it, and pin versions

Write the Dockerfile into the service directory with **unpinned** dependencies first,
then build to resolve versions:

```bash
cd services/my-service
docker build -t test-build-verify .
```

If the build fails, fix the Dockerfile and rebuild. Common failure modes include:

- **Permission/user constraints**: Some base images (e.g. `apache/airflow`) run
  as a non-root user and block `pip install` as root. Read the base image's
  documentation or inspect its Dockerfile to find the correct install pattern.
- **Missing system packages**: The base image may not include tools you expect
  (e.g. `curl`, `gcc`). Add them in a `RUN` layer before the step that needs them.
- **Package manager constraints**: Some images use `uv`, `pip`, or `pipx` with
  specific flags. Match the base image's conventions rather than assuming a
  generic `pip install` will work.

**After a successful build, capture the resolved versions and pin them in the
Dockerfile.** This satisfies hadolint DL3013 (pin versions in pip) and ensures
reproducible builds. Run:

```bash
docker run --rm test-build-verify pip freeze
```

Find the installed versions for each package in the `RUN pip install` line and
replace the unpinned names with pinned versions. For example:

```dockerfile
# BEFORE (unpinned — used for initial build verification only)
RUN pip install --no-cache-dir fastavro boto3 pika

# AFTER (pinned — from pip freeze output of successful build)
RUN pip install --no-cache-dir \
    fastavro==1.9.7 \
    boto3==1.35.99 \
    pika==1.3.2
```

Use the exact versions from `pip freeze` — do not fabricate version numbers.
If a package is already installed in the base image (common for Airflow images),
it will appear in `pip freeze` even if it wasn't in the `RUN pip install` line;
only pin packages that are explicitly listed in the install command.

Rebuild with pinned versions to confirm:

```bash
docker build -t test-build-verify .
```

The build must succeed with pinned versions. A build failure at authoring time
is cheap — a build failure during the small model's run wastes all its reflection
budget on a problem it cannot fix.

### Step 3: Run hadolint

```bash
hadolint services/my-service/Dockerfile
```

Fix any warnings. The Dockerfile must pass hadolint with **zero warnings**
— including DL3013 (pin versions). Because versions were pinned in Step 2,
DL3013 should not fire.

### Step 4: Write the test compose and verify the stack starts

With the Dockerfile verified, write the test compose file
(`service.test.compose.yml`) following the Two-Compose Pattern below. Then
verify the full stack starts successfully:

```bash
docker compose -f services/my-service/deployment/service.test.compose.yml up -d --wait --wait-timeout 120
```

If any container exits or fails its healthcheck, inspect the logs:

```bash
docker compose -f services/my-service/deployment/service.test.compose.yml logs
```

Common failures at this stage:
- **Missing env vars**: The service crashes on startup because a required
  configuration variable is missing from the compose environment block.
  Check the service's Settings class for all required fields and add them.
- **Wrong entrypoint**: The CMD doesn't match the base image's expectations.
  Check the base image docs for the correct startup command.
- **Port conflicts**: A port binding collides with a running host service.
  Change the host port in the compose file.

Fix any issues and re-run until all services start healthy. Then tear down:

```bash
docker compose -f services/my-service/deployment/service.test.compose.yml down -v --remove-orphans
docker rmi test-build-verify 2>/dev/null || true
```

Both the Dockerfile and the test compose stay on disk as scaffold. The deployment
task doc tells the model they already exist and instructs it to create only the
production compose file.

---

## The Two-Compose Pattern

Infrastructure tasks in a monorepo typically deal with two different compose needs:

**Production compose** (`service.compose.yml`) — used for actual deployment.
References the shared platform network (`external: true`), assumes MinIO,
RabbitMQ, and other infrastructure services are already running elsewhere. This
is what gets deployed to production.

**Test compose** (`service.test.compose.yml`) — used exclusively for the smoke
test. Fully self-contained: includes the service under test AND all infrastructure
it needs (MinIO, RabbitMQ, postgres, etc.) as local services on a local network.
Requires only Docker — not a running shared stack.

**Why two files?** The smoke test must be runnable without a pre-existing shared
stack. If the test compose referenced external services, any developer would need
to start the full platform just to test one service. By bundling dependencies
into the test compose, the smoke test is hermetic: `docker compose up` brings
everything it needs, `docker compose down -v` removes it completely.

### Detecting when to apply the two-compose pattern

Apply it whenever the production compose file:
- Declares `external: true` on any network, OR
- References services not defined in that file (e.g. `minio:9000` but no minio service)

When you detect this, the infrastructure task must create **both** files.

### Writing the test compose

The test compose reuses the same service images the project already uses — look
for existing compose files in the project to find the correct image tags and
environment variables.

```yaml
# service.test.compose.yml — self-contained, for smoke testing only
# DO NOT use this file for production deployment.

services:
  # The service under test
  my-service:
    build:
      context: ../../services/my-service
    environment:
      - MY_SERVICE_DEPENDENCY_URL=http://dependency:9000
    ports:
      - "8080:8080"
    depends_on:
      dependency:
        condition: service_healthy
    networks:
      - test-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 6

  # Local instance of a dependency — same image as used in production
  dependency:
    image: dependency-image:tag  # match the version from the production compose
    environment:
      - DEPENDENCY_ROOT_USER=testuser
      - DEPENDENCY_ROOT_PASSWORD=testpass
    networks:
      - test-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 10s
      timeout: 5s
      retries: 6

networks:
  test-net:
    # Local network — not external, fully owned by this test compose
    driver: bridge
```

Key rules for the test compose:
- **No `external: true` networks** — the network must be local and self-managed
- **Declare `healthcheck` on every service** — this lets `docker compose up --wait` block until the whole stack is ready
- **Use `condition: service_healthy` in `depends_on`** — ensures dependency ordering is correct
- **Give the service a port binding** — the smoke test script needs to reach it from the host

---

## Smoke Test Setup (Step 3b)

### Copy and configure the template

```bash
cp scripts/docker-smoke-test-template.sh docs/plans/my-tasks/smoke-test-my-service.sh
chmod +x docs/plans/my-tasks/smoke-test-my-service.sh
```

Edit the two configuration variables at the top:

```bash
COMPOSE_FILE="services/my-service/deployment/service.test.compose.yml"
HEALTH_URL="http://localhost:8080/health"
```

### Validate the smoke test script

The test compose is already validated (Step 3, Step 4 confirmed the stack starts).
Run the smoke test script to confirm it wires correctly to the compose file:

```bash
bash docs/plans/my-tasks/smoke-test-my-service.sh
```

The expected outcome against stubs: the Docker image builds (Dockerfile is scaffold
with real deps), the stack starts, but the health endpoint won't respond because
the service code isn't implemented yet. The smoke test should fail on health
timeout — not on build failure or container crash. This confirms the smoke test
script, Dockerfile, and test compose are all correctly wired.

Mark `"pre_validated": true` in the manifest.

### Manifest entry for a deployment task

```json
{
  "file": "18-task-8.1-docker-deployment.md",
  "task_id": "8.1",
  "title": "Docker Deployment",
  "phase": "Deployment",
  "files_created": [
    "services/my-service/deployment/service.compose.yml"
  ],
  "files_modified": [],
  "lint_cmd": "docs/plans/my-tasks/infra-lint.sh",
  "test_command": "bash docs/plans/my-tasks/smoke-test-my-service.sh",
  "pre_validated": true,
  "estimated_complexity": "simple",
  "depends_on": ["7.1"]
}
```

Note: no `test_file` field — infrastructure tasks don't have a pytest test file.
The `pre_validated` flag still applies: Claude Code must confirm the smoke test
script works (and fails appropriately against stubs) before marking it true.

---

## What the Small Model Must Produce

The small model's job for a deployment task is:

1. A production `service.compose.yml` that passes `docker compose config`

The model does NOT write the Dockerfile — that's scaffold, already on disk.
The model does NOT write the test compose — that's also scaffold.
The model does NOT write the smoke test script — Claude Code writes that in Step 3b.
The model's only output is the production compose file.

---

## Terraform and Kubernetes (Future)

These are out of scope for the current skill version. When you encounter Terraform
or Kubernetes YAML tasks:
- For Terraform: run `terraform validate` as the lint command; skip automated test
- For Kubernetes: run `kubectl apply --dry-run=client -f <file>` as lint; skip automated test
- Document `"mutation_gate": "skipped"` and `"mutation_gate_reason": "infrastructure config — no mutation tool applicable"` in the manifest

Add the lint command to the per-task `lint_cmd` field following the same pattern
as Docker tasks. Automated runtime testing for these is deferred to a future
skill iteration.
