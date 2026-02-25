# Wiring Completeness

The most common source of bugs in decomposed plans is missing wiring — a component gets created but never registered, imported, or connected to the thing that needs it. These gaps are invisible at the individual task level (each task passes its own tests) but produce broken systems when assembled.

This happens because plans are written phase by phase, and it's easy to focus on "create component X" without asking "where does X plug in?" When small models execute these tasks, they follow instructions literally — if the task doc doesn't say "add X to the registry," the model won't do it.

## The Core Rule

**Every component that gets created must also be connected to whatever consumes it.** The connection step goes either in the same task (if the consumer already exists) or in an explicit later task (if the consumer is created first). Never leave the connection implicit.

## Common Wiring Patterns

### Registry / List Registration

A central list or dict maps component types to implementations. When new components are added in later phases, they need an entry.

**Example:** A DAG has `EXTRACTORS = [StepsExtractor(), ...]`. Phase 3 creates the first 5 extractors and the DAG. Phase 5 adds 5 more extractors. Each Phase 5 task must include:
```markdown
**Files:**
- Create: `plugins/extractors/oxygen_saturation_extractor.py`
- Create: `tests/test_extractors/test_oxygen_saturation.py`
- Modify: `dags/health_connect_ingestion.py`
  (add `from plugins.extractors.oxygen_saturation_extractor import OxygenSaturationExtractor`
   and append `OxygenSaturationExtractor()` to `EXTRACTORS` list)
```

**Where this appears:** DAG task lists, plugin registries, handler maps, command dispatchers, factory classes, dependency injection containers, route tables.

### Import Map / Package Init

Adding a module to a package sometimes requires updating `__init__.py` for re-exports, or updating a barrel file that aggregates imports.

**Example:** A package uses `__init__.py` to expose its public API:
```python
# plugins/extractors/__init__.py
from .steps_extractor import StepsExtractor
from .blood_glucose_extractor import BloodGlucoseExtractor
```

When a later task adds `OxygenSaturationExtractor`, it must also update this init file.

**Where this appears:** Python package `__init__.py`, TypeScript barrel files (`index.ts`), module re-export files.

### Configuration / Settings

New components sometimes need new configuration entries (environment variables, settings fields, feature flags).

**Example:** Adding a new storage backend requires a new settings field:
```python
# config/settings.py
class Settings(BaseSettings):
    redis_url: str = "redis://localhost:6379"  # NEW — for the Redis cache task
```

**Where this appears:** Pydantic settings classes, environment files (`.env`, `.env.example`), Kubernetes ConfigMaps, Docker Compose environment sections.

### Docker / Infrastructure

New services or dependencies require updates to container definitions and orchestration files.

**Example:** Adding a RabbitMQ publisher means the Docker Compose file needs a RabbitMQ service, and the application container needs `RABBITMQ_URL` in its environment.

**Where this appears:** `docker-compose.yml`, `Dockerfile` (new dependencies, new COPY directives), Kubernetes manifests, Terraform resources.

### Router / Dispatcher Updates

When new message types, API endpoints, or event handlers are added, the routing layer needs updating.

**Example:** An ETL consumer routes messages by `file_format` field. Adding JSON support means:
1. Create `JsonParser` class (task A)
2. Update `ETLConsumer._get_parser_for_format()` to handle `"json"` (task B or same task)

If task A creates the parser but task B never materializes, the consumer silently ignores JSON messages.

**Where this appears:** API routers (FastAPI, Express), message consumers, event dispatchers, middleware chains, CLI command groups.

## Validation Checklist

Walk through this after writing the plan, before handing off to decomposition.

**For every file in the plan's "Create" lists:**

1. **Is it imported somewhere?** If you create `plugins/extractors/new_extractor.py`, does any other file import from it? If not, it's dead code — something needs to use it.

2. **Is it registered in a collection?** If the project has a list, dict, or config that enumerates components of this type, is the new one added? Check: DAG task lists, factory maps, router tables, plugin registries, package `__init__.py` re-exports.

3. **Does it need configuration?** If the new component requires an API key, URL, feature flag, or setting, is that setting added to the config/settings class and documented in `.env.example`?

4. **Does it need infrastructure?** If the new component talks to a service (database, queue, cache), is that service in Docker Compose / Kubernetes / Terraform?

**For every phase boundary (moving from Phase N to Phase N+1):**

5. **Do Phase N+1 tasks that create new instances of a Phase N pattern include the wiring step?** This is the most common gap. Phase 3 creates extractors and a DAG. Phase 5 creates more extractors. Do the Phase 5 tasks include "Modify: DAG file"?

6. **Are cross-phase dependencies explicit?** If Task 6.3 depends on the DAG structure from Task 5.1, does Task 6.3's prerequisites list Task 5.1? Don't rely on execution order alone — make the dependency visible.

**For integration and end-to-end tests:**

7. **Are they marked as deferred?** Integration tests that call functions from multiple components can't be written accurately before those components exist. Mark them as deferred so the agent-ready-plans skill handles them correctly.

## Example: Spotting a Gap

Consider this plan excerpt:

```
Phase 3: High-Priority Extractors
  Task 5.1: Steps Extractor (create + test)
  Task 5.2: Blood Glucose Extractor (create + test)

Phase 4: DAG Assembly
  Task 6.1: DAG with EXTRACTORS = [StepsExtractor(), BloodGlucoseExtractor()]

Phase 5: Remaining Extractors
  Task 7.1: Active Calories Extractor (create + test)    ← GAP
  Task 7.2: Distance Extractor (create + test)           ← GAP
```

Tasks 7.1 and 7.2 create extractors but don't modify the DAG. After execution, the DAG will only have 2 of 4 extractors registered. Small models executing tasks 7.1 and 7.2 won't know the DAG exists — their task docs only mention their own files.

**Fix:** Each Phase 5 task must include `Modify: dags/health_connect_ingestion.py` to add its extractor to the EXTRACTORS list and import block.
