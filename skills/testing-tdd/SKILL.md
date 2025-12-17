# Test-Driven Development Skill

Write and run tests for all code changes, ensuring they pass before marking work complete.

## Purpose

Ensure all code changes are covered by tests and that all tests pass. This is a **mandatory quality gate** - work is never complete until tests are written and passing.

## Prerequisites

- Testing framework must be configured (use `testing-setup` skill if needed)
- Project has a way to run tests (npm test, pytest, gradle test)

## Scope of Responsibility

**Tests must cover YOUR code changes, not entire codebase.**

### What You Must Test

**Code you add or modify:**
- ✓ New functions/methods: Unit tests required
- ✓ Modified functions: Update tests + verify they pass
- ✓ Bug fixes: Regression test that reproduces bug
- ✓ Refactoring: Existing tests must still pass

### What You Don't Need to Test

**Code you don't touch:**
- Pre-existing functions without tests: Create tracking issue, not required to add now
- Unrelated modules: Not your responsibility

**Rationale:**
- Touching a file for linting/security fixes ≠ requiring 100% test coverage
- Focus on ensuring YOUR changes are tested
- Don't let "add tests for entire file" block security/lint fixes

### Example Workflow

```bash
# You fix SQL injection in auth.ts (security fix)
# File has 5 functions, only 2 have tests

Required:
✓ Verify existing 2 tests still pass
✓ Add test for SQL injection fix (regression test)

NOT Required:
✗ Write tests for all 5 functions (would block security fix)

Recommended:
✓ Create issue: "Add test coverage for auth.ts functions X, Y, Z"
```

### Pre-Existing Test Failures

**If tests are failing BEFORE your changes:**

1. **Unrelated failures**: Create tracking issue, don't fix (not your scope)
2. **Related to file you're modifying**: Fix the test or code
3. **Unclear**: Ask in PR/discussion

**How to verify:**
```bash
# Checkout main branch
git checkout main

# Run tests
npm test

# If failures exist → not your responsibility
# If all pass → your changes must maintain passing state
```

## Process

### 1. Determine What Tests Are Needed

**For new features:**
- Unit tests for new functions/methods
- Integration tests for API endpoints or component interactions
- Edge case tests for boundary conditions

**For bug fixes:**
- Regression test that reproduces the bug
- Verify the fix actually resolves the issue

**For refactoring:**
- Ensure existing tests still pass
- Add tests for any new code paths introduced

### 2. Write Tests FIRST (When Possible)

For new features, follow TDD principles:
1. Write test describing expected behavior
2. Run test - it should fail (red)
3. Implement minimum code to pass test (green)
4. Refactor as needed (refactor)
5. Repeat

**Example - New TypeScript Function:**
```typescript
// tests/auth.test.ts - Write test first
describe('validateToken', () => {
  it('should return true for valid JWT', () => {
    const token = 'valid.jwt.token';
    expect(validateToken(token)).toBe(true);
  });

  it('should return false for expired token', () => {
    const token = 'expired.jwt.token';
    expect(validateToken(token)).toBe(false);
  });
});

// src/auth.ts - Then implement
export function validateToken(token: string): boolean {
  // Implementation here
}
```

**Example - Python Bug Fix:**
```python
# tests/test_parser.py - Write test reproducing bug
def test_parser_handles_empty_string():
    """Regression test for issue #123 - parser crashes on empty string"""
    result = parse_data("")
    assert result == []  # Should return empty list, not crash

# parser.py - Fix the bug
def parse_data(data: str) -> list:
    if not data:  # Add missing check
        return []
    return data.split(',')
```

### 3. Run Tests

Execute the test suite for the project:

**TypeScript/JavaScript:**
```bash
npm test
# Or for specific file:
npm test -- auth.test.ts
```

**Python:**
```bash
pytest
# Or for specific file:
pytest tests/test_parser.py
# Or with coverage:
pytest --cov=src tests/
```

**Kotlin/Android:**
```bash
./gradlew test
# Or for specific test:
./gradlew test --tests ExampleTest
```

### 4. Handle Test Failures

If tests fail:

**Read the failure message carefully:**
- What test failed?
- What was expected vs actual?
- Which line of code caused the failure?

**Debug systematically:**
1. Check if the test itself is correct
2. Verify the implementation logic
3. Add debug logging if needed
4. Fix the code or test
5. Re-run tests

**Example failure analysis:**
```
FAIL tests/auth.test.ts
  validateToken
    ✕ should return true for valid JWT (5 ms)

Expected: true
Received: undefined

  12 |   it('should return true for valid JWT', () => {
  13 |     const token = 'valid.jwt.token';
> 14 |     expect(validateToken(token)).toBe(true);
     |                                  ^

Fix: Function exists but doesn't return a value - add return statement
```

### 5. Iterate Until All Tests Pass

**NEVER** mark work complete until seeing:
```
✓ All tests passed
✓ No failing tests
✓ No skipped tests (unless intentional)
```

### 6. Verify Test Coverage

Check that your changes are actually tested:

**TypeScript/JavaScript with Jest:**
```bash
npm test -- --coverage
```

**Python with pytest:**
```bash
pytest --cov=src --cov-report=term-missing
```

Look for:
- New files have >80% coverage
- Critical paths have 100% coverage
- Edge cases are tested

## Test Quality Guidelines

### Good Tests Are:

**Independent:**
- Don't depend on other tests
- Can run in any order
- Clean up after themselves

**Repeatable:**
- Same input = same output
- No flaky tests
- No reliance on external services (use mocks)

**Fast:**
- Unit tests should be milliseconds
- Integration tests under a second
- Use mocks for slow operations

**Readable:**
- Clear test names
- Descriptive assertions
- Obvious what's being tested

### Example - Good vs Bad Tests

**Bad Test:**
```typescript
it('test 1', () => {
  const x = func(5);
  expect(x).toBe(10);
});
```

**Good Test:**
```typescript
it('should double the input number', () => {
  const input = 5;
  const result = doubleNumber(input);
  expect(result).toBe(10);
});
```

## Coverage Expectations

**Minimum requirements:**
- **New functions:** Must have unit tests
- **API changes:** Must have integration tests
- **Bug fixes:** Must have regression test
- **Public APIs:** 100% coverage required
- **Internal utilities:** 80%+ coverage recommended

**Not everything needs tests:**
- Simple getters/setters
- Generated code
- Third-party integrations (mock instead)
- UI layout code (consider E2E tests instead)

## Common Testing Patterns

### Mocking External Dependencies

**TypeScript/Jest:**
```typescript
jest.mock('../api/client');

it('should fetch user data', async () => {
  const mockClient = require('../api/client');
  mockClient.get.mockResolvedValue({ id: 1, name: 'John' });
  
  const user = await fetchUser(1);
  expect(user.name).toBe('John');
});
```

**Python/pytest:**
```python
from unittest.mock import Mock, patch

def test_fetch_user(mock_get):
    mock_get.return_value = {'id': 1, 'name': 'John'}
    
    user = fetch_user(1)
    assert user['name'] == 'John'
```

### Testing Async Code

**TypeScript:**
```typescript
it('should handle async operations', async () => {
  const result = await asyncFunction();
  expect(result).toBe('expected');
});
```

**Python:**
```python
import pytest

@pytest.mark.asyncio
async def test_async_function():
    result = await async_function()
    assert result == 'expected'
```

### Testing Error Cases

```typescript
it('should throw error for invalid input', () => {
  expect(() => processData(null)).toThrow('Invalid input');
});
```

## Output Confirmation

Before proceeding to next quality gate:

```
✓ Tests written for all code changes
✓ All tests passing (X passed, 0 failed)
✓ Coverage meets requirements (X% for new code)
✓ No skipped or disabled tests
```

## CRITICAL RULE

**NEVER** claim work is complete with failing tests IN YOUR SCOPE.

**For tests related to your changes:**
1. Fix the code, OR
2. Fix the test, OR
3. Explain why the test is wrong and needs updating

**For pre-existing test failures:**
1. Verify they existed before your changes (`git checkout main && npm test`)
2. Create tracking issue with details
3. Don't block on these (not your responsibility)

**Your changeset must not introduce NEW test failures.**

**How to verify:**
```bash
# Tests on main
git stash
git checkout main
npm test > /tmp/main-test-results.txt

# Tests with your changes
git checkout -
git stash pop
npm test > /tmp/my-test-results.txt

# Compare - should have same or fewer failures
diff /tmp/main-test-results.txt /tmp/my-test-results.txt
```

But **always** end with all tests passing (or pre-existing failures documented).

## Integration with Other Skills

After tests pass:
- Proceed to `linting-check` skill
- Continue to `security-check` skill
- All three must pass for `feature-development` completion
