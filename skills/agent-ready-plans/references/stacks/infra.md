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

### Validate the smoke test before embedding in the task doc

Run it from the project root to confirm it works with the stub implementation:

```bash
bash docs/plans/my-tasks/smoke-test-my-service.sh
```

The expected outcome against stubs: the Dockerfile may not build correctly yet
(missing Python packages, missing files), which is fine — the smoke test failing
against stubs means it will catch the model's implementation. If the stub
Dockerfile happens to build, the health endpoint won't respond (the service isn't
implemented), so the timeout will fire and the test will fail. Either failure mode
is correct.

Mark `"pre_validated": true` in the manifest once you've confirmed the test fails
for the right reason against the stub (build failure or health endpoint timeout).

### Manifest entry for an infrastructure task

```json
{
  "file": "18-task-8.1-docker-deployment.md",
  "task_id": "8.1",
  "title": "Docker Deployment",
  "phase": "Deployment",
  "files_created": [
    "services/my-service/Dockerfile",
    "services/my-service/deployment/service.compose.yml",
    "services/my-service/deployment/service.test.compose.yml"
  ],
  "files_modified": [],
  "lint_cmd": "docs/plans/my-tasks/infra-lint.sh",
  "test_command": "bash docs/plans/my-tasks/smoke-test-my-service.sh",
  "pre_validated": true,
  "estimated_complexity": "moderate",
  "depends_on": ["7.1"]
}
```

Note: no `test_file` field — infrastructure tasks don't have a pytest test file.
The `pre_validated` flag still applies: Claude Code must confirm the smoke test
script works (and fails appropriately against stubs) before marking it true.

---

## What the Small Model Must Produce

The small model's job for an infrastructure task is:

1. A working `Dockerfile` that passes hadolint with zero errors
2. A production `service.compose.yml` that passes `docker compose config`
3. A self-contained `service.test.compose.yml` that passes `docker compose config`
   AND allows `docker compose up --wait` to succeed with the service healthy

The model does NOT write the smoke test script — Claude Code writes that in Step 3b.
The model also does NOT modify the smoke test script. The model's output is the
infrastructure files; the smoke test validates them.

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
