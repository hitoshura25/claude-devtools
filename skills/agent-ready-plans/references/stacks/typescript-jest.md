# TypeScript + Jest Stack Reference

Read this file when:
- The project's language is TypeScript or JavaScript and test framework is Jest (or Vitest)
- Setting up tooling (SKILL.md Steps 2–3)
- Creating test fixtures (Step 3)
- Writing stubs for mutation testing (Step 3b)

---

## Package Manager Setup

```bash
cd services/my-service
npm install --save-dev jest ts-jest @types/jest eslint typescript
# or with pnpm:
pnpm add -D jest ts-jest @types/jest eslint typescript
```

Minimal `jest.config.ts`:
```typescript
export default {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.ts'],
};
```

Verify:
```bash
npx eslint src/
npx jest --passWithNoTests
```

---

## Lint Wrapper

ESLint ignores non-JS/TS files by default, so aider passing `Dockerfile` or `package.json` alongside `.ts` files typically doesn't cause issues. Test this with your specific ESLint config — if it errors on non-source files, create a wrapper analogous to `lint-ruff-wrapper.sh` that filters to `.ts`/`.js` only.

**Manifest tooling:**
```json
{
  "tooling": {
    "lint_cmd": "npx eslint --fix",
    "test_cmd": "cd services/my-service && npx jest --passWithNoTests",
    "language": "typescript",
    "framework": "jest",
    "linter": "eslint"
  }
}
```

---

## Stub Design

```typescript
export class RecordFilter {
  filter(rows: Row[], watermark: number): Row[] {
    throw new Error('not implemented');
  }

  count(rows: Row[]): number {
    throw new Error('not implemented');
  }
}
```

**Module-level singletons:** If a module exports a singleton instantiated at the top level (e.g., `export const config = new Config()`), importing that module at test collection time will run the constructor. If it requires env vars or network, tests fail to load.

```typescript
// WRONG stub — Config() may require env vars
export const config = new Config();

// CORRECT stub — safe to import without env vars
export const config = null as unknown as Config;
```

---

## Mocking Framework Modules

When a framework is not installed, use Jest's `moduleNameMapper` in `jest.config.ts` to redirect imports to mock files:

```typescript
// jest.config.ts
export default {
  moduleNameMapper: {
    '^some-framework$': '<rootDir>/tests/__mocks__/some-framework.ts',
    '^some-framework/(.*)$': '<rootDir>/tests/__mocks__/some-framework/$1.ts',
  },
};
```

Or use automatic mocking at the top of the test file:
```typescript
jest.mock('some-framework');
jest.mock('some-framework/sub-module');
```

**Critical rule:** Every distinct import path must be mocked separately. `jest.mock('framework')` does not automatically mock `framework/sub-module`.

**Verification step:**
```bash
npx ts-node -e "import './src/my-module'"
```

---

## External Dependency Mock Fixtures

Use Jest's `jest.fn()` and `jest.spyOn()` for mocks. For complex clients, create factory functions in `tests/fixtures/`:

```typescript
// tests/fixtures/mock-s3.ts
export function createMockS3Client() {
  const mockPutObject = jest.fn().mockResolvedValue({ ETag: '"mock-etag"' });
  const mockClient = { putObject: mockPutObject } as unknown as S3Client;

  return {
    client: mockClient,
    capturedBody: () => mockPutObject.mock.calls[0][0].Body,
    capturedKey:  () => mockPutObject.mock.calls[0][0].Key,
  };
}
```

Usage in tests:
```typescript
import { createMockS3Client } from '../fixtures/mock-s3';

jest.mock('@aws-sdk/client-s3');

describe('MyWriter', () => {
  it('uploads to S3', async () => {
    const mockS3 = createMockS3Client();
    const writer = new MyWriter(mockS3.client);
    await writer.write(data);
    expect(mockS3.capturedKey()).toBe('expected/key.avro');
  });
});
```

---

## Mutation Testing — Stryker

```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner
# or for Vitest:
npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner
```

**Minimal `stryker.config.mjs`:**
```js
export default {
  testRunner: 'jest',
  coverageAnalysis: 'perTest',
  mutate: ['src/mymodule/filter.ts'],
};
```

**Run:**
```bash
npx stryker run
```

Target: ≥80% mutation score before embedding tests in task docs.
