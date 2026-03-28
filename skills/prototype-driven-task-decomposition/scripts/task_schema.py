"""
Prototype-Driven Task Decomposition — Canonical Task Schema

This is the source of truth for the structure of implementation tasks produced
by the prototype-driven-task-decomposition skill. The prototype-driven-implementation
pipeline (LangGraph + Aider) imports this schema to validate task payloads before
routing them to implementing models.

Usage:
    from task_schema import TaskDecomposition, Task

    # Validate a task decomposition payload
    decomposition = TaskDecomposition.model_validate_json(json_string)

    # Access individual tasks in dependency order
    for task in decomposition.tasks_in_order():
        print(task.id, task.title)

    # Get only test tasks or only implementation tasks
    test_tasks = [t for t in decomposition.tasks if t.task_type == TaskType.TEST]
    impl_tasks = [t for t in decomposition.tasks if t.task_type == TaskType.IMPLEMENTATION]
"""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field, model_validator


class TaskType(str, Enum):
    """Whether this task writes tests or writes implementation code.

    The pipeline uses this to determine success criteria:
    - TEST tasks write test files. Success = tests are syntactically valid,
      importable, and fail for the right reasons (the implementation doesn't
      exist yet or is a stub).
    - IMPLEMENTATION tasks write production code. Success = all previously-
      written tests pass, plus lint passes.

    This enforces a strict TDD workflow: tests are always written before the
    code that makes them pass.
    """
    TEST = "test"
    IMPLEMENTATION = "implementation"


class TaskPhase(str, Enum):
    """Logical grouping for execution ordering.

    Tasks within the same phase can potentially run in parallel (if no
    inter-task dependencies exist). Phases execute sequentially.
    """
    SCAFFOLD = "scaffold"           # Project structure, config files, dependencies
    CORE = "core"                   # Core business logic and data models
    INTEGRATION = "integration"     # Wiring components together, API endpoints
    TESTING = "testing"             # Test infrastructure and test files
    INFRASTRUCTURE = "infrastructure"  # Dockerfile, CI/CD, deployment config


class FileOperation(str, Enum):
    """What the implementing model should do with a file."""
    CREATE = "create"
    MODIFY = "modify"


class FileChange(BaseModel):
    """A single file that a task creates or modifies."""
    path: str = Field(
        description="Path relative to project root (e.g., 'src/health_sync/client.py')"
    )
    operation: FileOperation
    description: str = Field(
        description="What this file does or what changes are being made to it"
    )


class PrototypeReference(BaseModel):
    """A pointer to a specific prototype file that demonstrates a pattern
    the implementing model should follow."""
    file: str = Field(
        description="Path relative to the prototype directory "
                    "(e.g., 'fetch.py', 'tests/test_fetch.py')"
    )
    what_to_reference: str = Field(
        description="What pattern or approach to copy from this file. Be specific — "
                    "'the API response parsing at lines 23-31' not 'the fetch logic'"
    )


class TestCriterion(BaseModel):
    """A specific test that must pass for the task to be considered complete.

    On a TEST task: this describes a test case to write.
    On an IMPLEMENTATION task: this describes an existing test that must pass
    after the implementation is complete.
    """
    description: str = Field(
        description="What the test verifies (e.g., 'Health sync client returns "
                    "parsed records when API returns valid JSON')"
    )
    test_file: str = Field(
        description="Path where this test lives (or will live), relative to project root"
    )
    test_type: str = Field(
        description="'unit', 'integration', or 'e2e'"
    )


class SecurityConsideration(BaseModel):
    """A security concern specific to this task that the implementing model
    must address."""
    concern: str = Field(
        description="What the security issue is (e.g., 'API key must not be "
                    "hardcoded or logged')"
    )
    mitigation: str = Field(
        description="How to address it (e.g., 'Read from environment variable, "
                    "redact in log output')"
    )


class Task(BaseModel):
    """A single implementation task.

    Each task should be completable by a local model (Qwen/Codestral) in a single
    focused session. If a task feels too large, it should be split. If it feels
    trivial (< 5 minutes of work), it should be merged with a related task.

    Tasks follow a strict TDD discipline:
    - A 'test' task writes test files. It never writes production code.
    - An 'implementation' task writes production code. It never writes test files.
      It runs previously-written tests to confirm correctness.

    The implementing model receives: this task's fields, access to the prototype
    directory, and the project's existing codebase. It does NOT receive the full
    design doc or other tasks — each task must be self-contained.
    """
    id: str = Field(
        description="Unique identifier, e.g., 'task-01', 'task-02'"
    )
    title: str = Field(
        description="Short, action-oriented title "
                    "(e.g., 'Create health sync API client')"
    )
    task_type: TaskType = Field(
        description="Whether this task writes tests or implementation code. "
                    "'test' tasks write test files and verify they compile/import. "
                    "'implementation' tasks write production code and run existing tests."
    )
    phase: TaskPhase
    description: str = Field(
        description="What this task accomplishes and why. Include enough context "
                    "that the implementing model understands the task without seeing "
                    "the full design doc. 2-4 sentences."
    )
    depends_on: list[str] = Field(
        default_factory=list,
        description="List of task IDs that must complete before this task starts. "
                    "Empty list means no dependencies. Implementation tasks must "
                    "depend on their corresponding test task."
    )
    files: list[FileChange] = Field(
        min_length=1,
        description="Files this task creates or modifies. Every task must touch "
                    "at least one file. Test tasks create test files only. "
                    "Implementation tasks create production files only."
    )
    prototype_references: list[PrototypeReference] = Field(
        default_factory=list,
        description="Prototype files to reference for patterns. Not every task "
                    "will have prototype references (e.g., config-only tasks)."
    )
    tests: list[TestCriterion] = Field(
        default_factory=list,
        description="For test tasks: the test cases to write. "
                    "For implementation tasks: the existing tests that must pass."
    )
    acceptance_criteria: list[str] = Field(
        min_length=1,
        description="Concrete, verifiable conditions for task completion. "
                    "Test tasks: 'test file is importable', 'tests fail because "
                    "implementation does not exist'. Implementation tasks: "
                    "'all tests pass', 'lint passes'."
    )
    security_considerations: list[SecurityConsideration] = Field(
        default_factory=list,
        description="Security concerns specific to this task. Empty for tasks with "
                    "no security implications (e.g., adding a config file)."
    )

    @model_validator(mode="after")
    def lint_passes_in_acceptance(self) -> "Task":
        """Every task should include 'lint passes' in acceptance criteria."""
        has_lint = any("lint" in c.lower() for c in self.acceptance_criteria)
        if not has_lint:
            self.acceptance_criteria.append("Lint passes with zero errors")
        return self

    @model_validator(mode="after")
    def implementation_depends_on_test(self) -> "Task":
        """Warn if an implementation task has tests but no test task dependency.
        This is a soft check — the decomposition-level validator handles strict
        enforcement since it can see all tasks."""
        # No enforcement here — the TaskDecomposition validator handles pairing
        return self


class TaskDecomposition(BaseModel):
    """The complete output of the task decomposition skill.

    Contains metadata linking back to the design doc and prototype, plus the
    ordered list of implementation tasks.

    Tasks follow TDD discipline: for every component with testable logic,
    there is a test task that writes the tests, followed by an implementation
    task that writes the code to make them pass. The implementation task
    depends on its test task.
    """
    feature_name: str = Field(
        description="Kebab-case feature name (e.g., 'health-data-sync')"
    )
    design_doc_path: str = Field(
        description="Path to the design doc this decomposition is based on "
                    "(e.g., 'docs/design/health-data-sync.md')"
    )
    prototype_path: str = Field(
        description="Path to the prototype directory "
                    "(e.g., 'prototypes/health-data-sync/')"
    )
    summary: str = Field(
        description="One paragraph summarizing what the implementation will produce "
                    "and the overall approach."
    )
    tasks: list[Task] = Field(
        min_length=1,
        description="Implementation tasks in recommended execution order."
    )

    @model_validator(mode="after")
    def validate_dependency_graph(self) -> "TaskDecomposition":
        """Ensure all depends_on references point to valid task IDs and
        there are no circular dependencies."""
        task_ids = {t.id for t in self.tasks}
        for task in self.tasks:
            for dep in task.depends_on:
                if dep not in task_ids:
                    raise ValueError(
                        f"Task '{task.id}' depends on '{dep}' which doesn't exist"
                    )

        # Check for cycles via topological sort
        visited: set[str] = set()
        in_progress: set[str] = set()
        task_map = {t.id: t for t in self.tasks}

        def visit(task_id: str) -> None:
            if task_id in visited:
                return
            if task_id in in_progress:
                raise ValueError(
                    f"Circular dependency detected involving task '{task_id}'"
                )
            in_progress.add(task_id)
            for dep in task_map[task_id].depends_on:
                visit(dep)
            in_progress.remove(task_id)
            visited.add(task_id)

        for t in self.tasks:
            visit(t.id)

        return self

    @model_validator(mode="after")
    def validate_tdd_pairing(self) -> "TaskDecomposition":
        """Validate that implementation tasks with tests depend on a test task
        that writes those tests."""
        task_map = {t.id: t for t in self.tasks}
        for task in self.tasks:
            if task.task_type == TaskType.IMPLEMENTATION and task.tests:
                # Check that at least one dependency is a test task
                has_test_dep = any(
                    task_map[dep].task_type == TaskType.TEST
                    for dep in task.depends_on
                    if dep in task_map
                )
                if not has_test_dep:
                    raise ValueError(
                        f"Implementation task '{task.id}' has tests but does not "
                        f"depend on any test task. TDD requires tests to be "
                        f"written before implementation."
                    )
        return self

    def tasks_in_order(self) -> list[Task]:
        """Return tasks in topological order (dependencies first)."""
        task_map = {t.id: t for t in self.tasks}
        visited: set[str] = set()
        order: list[Task] = []

        def visit(task_id: str) -> None:
            if task_id in visited:
                return
            for dep in task_map[task_id].depends_on:
                visit(dep)
            visited.add(task_id)
            order.append(task_map[task_id])

        for t in self.tasks:
            visit(t.id)

        return order
