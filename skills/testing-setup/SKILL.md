# Testing Setup Skill

Ensure the project has a working test framework configured.

## Purpose

Before writing or running tests, verify that a test framework is installed and properly configured. If not, set up an appropriate framework for the project's language.

## Detection Logic

Check for test framework indicators based on project type:

### TypeScript/JavaScript Projects
Look for:
- `jest.config.js`, `jest.config.ts`, or `vitest.config.ts` config files
- `"test"` script in `package.json`
- Test dependencies in `package.json`: `jest`, `vitest`, `@types/jest`

### Python Projects
Look for:
- `pytest.ini`, `setup.cfg`, or `pyproject.toml` with `[tool.pytest]` section
- Test dependencies: `pytest` in requirements or pyproject.toml

### Kotlin/Android Projects
Look for:
- Test dependencies in `build.gradle.kts`:
  - `testImplementation("junit:junit:...")`
  - `testImplementation("org.junit.jupiter:...")`
- `src/test/` directory structure

## Setup Actions

If no test framework is detected, install and configure one:

### For TypeScript/JavaScript

**Option 1: Jest (most common)**
```bash
npm install --save-dev jest @types/jest ts-jest
npx ts-jest config:init
```

**Option 2: Vitest (modern alternative)**
```bash
npm install --save-dev vitest @vitest/ui
```

Add test script to `package.json`:
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch"
  }
}
```

Create `jest.config.js`:
```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts'
  ]
};
```

### For Python

```bash
pip install pytest pytest-cov
```

Create `pytest.ini`:
```ini
[pytest]
testpaths = tests
python_files = test_*.py *_test.py
python_classes = Test*
python_functions = test_*
addopts = 
    --verbose
    --cov=.
    --cov-report=term-missing
    --cov-report=html
```

Or add to `pyproject.toml`:
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
addopts = [
    "--verbose",
    "--cov=.",
    "--cov-report=term-missing"
]
```

### For Kotlin/Android

Ensure `build.gradle.kts` has:
```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.junit.jupiter:junit-jupiter:5.9.0")
    testImplementation("org.mockito:mockito-core:5.0.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.0.0")
}

tasks.test {
    useJUnitPlatform()
}
```

## Verification

After setup, verify the framework works:

```bash
# TypeScript/JavaScript
npm test

# Python
pytest

# Kotlin/Android
./gradlew test
```

The command should run successfully, even if there are no tests yet (should report "0 tests" or similar).

## Create Example Test

If setup is fresh, create a simple example test to verify it works:

### TypeScript
Create `tests/example.test.ts`:
```typescript
describe('Example Test Suite', () => {
  it('should verify testing works', () => {
    expect(true).toBe(true);
  });
});
```

### Python
Create `tests/test_example.py`:
```python
def test_example():
    """Verify testing framework works."""
    assert True
```

### Kotlin
Create `src/test/kotlin/ExampleTest.kt`:
```kotlin
import org.junit.jupiter.api.Test
import kotlin.test.assertTrue

class ExampleTest {
    @Test
    fun exampleTest() {
        assertTrue(true, "Testing framework works")
    }
}
```

## Output Confirmation

Once testing is configured and verified, confirm:

```
✓ Testing framework configured: [jest/pytest/junit]
✓ Test command works: [npm test/pytest/gradle test]
✓ Example test passes
```

## Edge Cases

**Monorepo with multiple packages:**
- Each package may need its own test configuration
- Check for workspace-level test scripts vs package-level

**Existing tests but no framework:**
- User may have written tests manually
- Still need to install framework to run them

**Multiple test frameworks:**
- Some projects use both unit and integration test frameworks
- Document both, ensure both work

## Next Steps

After testing is set up, you can proceed to:
- Writing tests for new features (see `testing-tdd` skill)
- Running tests as part of quality gates
- Setting up CI/CD test runs
