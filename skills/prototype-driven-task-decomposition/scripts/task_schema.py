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
"""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field, model_validator


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
    """A specific test that must pass for the task to be considered complete."""
    description: str = Field(
        description="What the test verifies (e.g., 'Health sync client returns "
                    "parsed records when API returns valid JSON')"
    )
    test_file: str = Field(
        description="Path where this test should live, relative to project root"
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
    phase: TaskPhase
    description: str = Field(
        description="What this task accomplishes and why. Include enough context "
                    "that the implementing model understands the task without seeing "
                    "the full design doc. 2-4 sentences."
    )
    depends_on: list[str] = Field(
        default_factory=list,
        description="List of task IDs that must complete before this task starts. "
                    "Empty list means no dependencies."
    )
    files: list[FileChange] = Field(
        min_length=1,
        description="Files this task creates or modifies. Every task must touch "
                    "at least one file."
    )
    prototype_references: list[PrototypeReference] = Field(
        default_factory=list,
        description="Prototype files to reference for patterns. Not every task "
                    "will have prototype references (e.g., config-only tasks)."
    )
    tests: list[TestCriterion] = Field(
        default_factory=list,
        description="Tests that must pass for this task to be complete. Some tasks "
                    "(scaffold, config) may not have tests."
    )
    acceptance_criteria: list[str] = Field(
        min_length=1,
        description="Concrete, verifiable conditions for task completion. At minimum: "
                    "'lint passes', 'tests pass'. Include feature-specific criteria too."
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


class TaskDecomposition(BaseModel):
    """The complete output of the task decomposition skill.

    Contains metadata linking back to the design doc and prototype, plus the
    ordered list of implementation tasks.
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
