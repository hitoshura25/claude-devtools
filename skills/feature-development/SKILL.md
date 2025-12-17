# Feature Development Skill

Complete workflow for implementing features with mandatory quality gates.

## Purpose

This is the **master orchestration skill** that ensures all code changes go through proper quality gates before completion. Use this skill for implementing new features, bug fixes, or refactoring.

## Overview

Feature development follows a strict workflow:

```
0. Specification (CONDITIONAL)
   ├─ Assess complexity
   ├─ Create spec if needed (or user requested)
   └─ Honor user preference (create/skip)
   ↓
1. Implement Feature
   ↓
2. Testing Phase (MANDATORY)
   ├─ Setup tests if needed
   └─ Write and run tests
   ↓
3. Linting Phase (MANDATORY)
   ├─ Setup linter if needed
   └─ Run linting and fix issues
   ↓
4. Security Phase (MANDATORY)
   ├─ Setup security tools if needed
   └─ Run security scans
   ↓
5. Update Spec (if created)
   └─ Mark completion status
   ↓
6. Completion ✓
```

**All mandatory phases must pass. No exceptions.**

## Critical Concept: Scope of Responsibility

**Quality gates apply to FILES YOU MODIFY, not entire codebase.**

### The Rule

When you modify a file:
- **Security**: Fix ALL critical/high issues in that file
- **Linting**: Fix ALL errors in that file
- **Testing**: Ensure tests pass (add tests for YOUR changes)

### What This Means

**You DON'T need to:**
- Fix security issues in files you don't touch
- Lint the entire codebase
- Write tests for unrelated code

**You DO need to:**
- Fix all issues in files you modify (leave them better than you found them)
- Ensure your new code meets all quality gates
- Document scope clearly

### Example

```bash
Feature: Add user authentication to auth.ts

Files you'll modify:
- src/auth.ts (main implementation)
- src/types/user.ts (add User type)
- tests/auth.test.ts (add tests)

Quality gate scope:
✓ Fix ALL security issues in these 3 files
✓ Fix ALL lint errors in these 3 files
✓ Ensure all tests pass (including new tests)

NOT required:
✗ Fix security issues in src/api.ts (you didn't touch it)
✗ Lint entire src/ directory (only your 3 files)
```

### Verification Command

```bash
# Your scope
git diff --name-only main

# Run quality gates ONLY on these files
semgrep --config=auto $(git diff --name-only main)
npm run lint -- $(git diff --name-only main | grep '\.ts$')
npm test  # All tests must pass, add tests for your changes
```

## Process

### Phase 0: Specification (CONDITIONAL)

**This phase creates a specification document to preserve context across sessions.**

**When to create a spec:**

The AI agent should intelligently decide based on complexity:

**Always create spec for:**
- Complex features (>3 files affected, architectural decisions)
- Features requiring codebase research
- Multi-session work (likely >30 minutes)
- Security-critical features (authentication, authorization, payment)
- Breaking changes or major refactoring

**Usually create spec for:**
- New API endpoints or services
- Database schema changes
- Integration with external services

**May skip spec for:**
- Simple bug fixes (single file, clear fix)
- Trivial changes (<20 lines, single function)
- Documentation updates only

**Always honor user preference:**
- User says "create spec" → Always create
- User says "no spec" → Never create
- User doesn't specify → AI decides based on complexity

**How to create spec:**

1. **Assess complexity** of the feature request
2. **If spec is needed** (or user requested):
   - Read and follow `../spec-creation/SKILL.md`
   - Create spec file in `./specs/YYYY-MM-DD-feature-name.md`
   - Choose appropriate detail level (default: Level 2)
   - Confirm with user before proceeding
3. **If skipping spec**:
   - Proceed directly to Phase 1 (Implementation)

**Spec detail levels:**
- **Level 1**: High-level plan (simple features)
- **Level 2**: Detailed implementation plan (DEFAULT - enables session resumption)
- **Level 3**: Complete specification (complex features with architecture decisions)

**Default choice**: Level 2 provides enough detail for new AI agents to resume work without prior context.

**Example decision:**
```
User: "/devtools:develop Add user authentication"

AI Analysis:
- Affects 5+ files
- Security-critical
- Architectural decisions needed (JWT vs sessions)
→ Decision: CREATE SPEC (Level 2)

AI: "Creating specification for this feature to ensure proper
planning and enable session resumption..."

[Creates specs/2024-12-05-user-authentication.md]
```

**Checkpoint: Spec created (if applicable)**
```
✓ Complexity assessed
✓ Spec created in ./specs/ (if needed)
✓ User confirmed (or proceeding automatically)
✓ Ready to implement
```

### Phase 1: Implement Feature

**Understand the requirement:**
- Read the feature request carefully
- Ask clarifying questions if needed
- Identify affected components

**Follow project patterns:**
- Match existing code style
- Use project's established patterns
- Keep changes focused and atomic
- Don't refactor unrelated code

**Write clean code:**
- Meaningful variable names
- Clear function signatures
- Appropriate comments for complex logic
- Error handling where needed

**Example - Adding Authentication:**
```typescript
// Good: Clear, focused implementation
export async function authenticateUser(
  email: string,
  password: string
): Promise<User | null> {
  const user = await db.users.findByEmail(email);
  if (!user) return null;
  
  const isValid = await bcrypt.compare(password, user.passwordHash);
  return isValid ? user : null;
}
```

### Phase 2: Testing (MANDATORY)

**2a. Ensure Test Framework Exists**

Check if testing is configured:
```bash
# TypeScript: Look for jest.config.js or vitest.config.ts
# Python: Look for pytest.ini or pyproject.toml
# Kotlin: Check build.gradle.kts for test dependencies
```

**If not configured:**
- Read and follow `../testing-setup/SKILL.md`
- Set up appropriate test framework
- Verify tests can run

**2b. Write and Run Tests**

Once testing framework is ready:
- Read and follow `../testing-tdd/SKILL.md`
- Write tests for the implemented feature
- Run all tests
- Fix failures
- Verify all tests pass

**Required test coverage:**
- ✓ Unit tests for new functions
- ✓ Integration tests for API changes
- ✓ Regression tests for bug fixes
- ✓ Edge case tests for critical logic

**Checkpoint: All tests must pass**
```
✓ Test framework configured
✓ Tests written for feature
✓ All tests passing (X passed, 0 failed)
✓ Coverage acceptable
```

### Phase 3: Linting (MANDATORY)

**3a. Ensure Linter Exists**

Check if linting is configured:
```bash
# TypeScript: Look for .eslintrc.js
# Python: Look for ruff.toml or .pylintrc
# Kotlin: Look for ktlint in build.gradle.kts
```

**If not configured:**
- Read and follow `../linting-setup/SKILL.md`
- Set up appropriate linter
- Verify linter can run

**3b. Run Linting and Fix Issues**

Once linter is ready:
- Read and follow `../linting-check/SKILL.md`
- Run linter on code changes
- Auto-fix what's possible
- Manually fix remaining issues
- Document any exceptions
- Verify clean lint report

**Checkpoint: Linting must be clean**
```
✓ Linter configured
✓ Linting executed
✓ All issues fixed or documented
✓ No errors remaining
```

### Phase 4: Security (MANDATORY)

**4a. Ensure Security Tools Exist**

Check if security scanning is configured:
```bash
# Look for: semgrep, osv-scanner
# Check: Can run security scans
```

**If not configured:**
- Read and follow `../security-setup/SKILL.md`
- Install Semgrep and OSV-Scanner
- Set up security scan scripts
- Run initial baseline scan

**4b. Run Security Scans**

Once security tools are ready:
- Read and follow `../security-check/SKILL.md`
- Run Semgrep (static analysis)
- Run OSV-Scanner (dependency check)
- Run language-specific audits
- Address all critical/high findings
- Document accepted risks for medium/low

**Checkpoint: Security scan must pass**
```
✓ Security tools configured
✓ Static analysis passed
✓ Dependency scan passed
✓ No critical/high vulnerabilities
✓ Medium findings documented/accepted
```

## Completion Checklist

Before claiming work is done, verify **ALL** of these:

### Specification (if created)
- [ ] Spec file created in ./specs/ (if applicable)
- [ ] Spec updated with final state
- [ ] All checkboxes in spec marked complete
- [ ] Session resumption context updated

### Feature Implementation
- [ ] Feature fully implemented as specified
- [ ] Code follows project patterns and style
- [ ] No unrelated changes included
- [ ] Error handling is appropriate

### Testing
- [ ] Test framework is configured
- [ ] Tests written for all new code
- [ ] Tests written for edge cases
- [ ] All tests passing (0 failures)
- [ ] Coverage meets requirements

### Linting
- [ ] Linter is configured
- [ ] Modified files pass ALL lint checks (no "unless documented" escape)
- [ ] Formatting is consistent in modified files
- [ ] Pre-existing errors in other files: tracked but not blocking

### Security
- [ ] Security tools are configured
- [ ] No critical/high vulnerabilities in modified files (MANDATORY FIX)
- [ ] Medium findings in modified files: fixed OR tracked with issue
- [ ] Vulnerabilities in unmodified files: acknowledged/tracked
- [ ] Dependencies are up to date
- [ ] No hardcoded secrets
- [ ] Clear documentation of scope in PR

### Documentation (if applicable)
- [ ] Code comments for complex logic
- [ ] API documentation updated
- [ ] README updated if needed
- [ ] Migration guide if breaking changes

## Failure Handling

If any phase fails:

**Testing Failures:**
```
Tests failed → Fix code or test → Re-run tests → Repeat until passing
```

**Linting Failures:**
```
Lint errors → Auto-fix → Manual fix → Document exceptions → Re-run lint → Repeat until clean
```

**Security Failures:**
```
Vulnerabilities found → Fix code → Update dependencies → Document risks → Re-run scan → Repeat until acceptable
```

**NEVER skip a phase. NEVER proceed with failures.**

## Example: Complete Feature Development Flow

**Scenario:** Add password reset functionality

### 1. Implement Feature

```typescript
// src/auth/passwordReset.ts
export async function requestPasswordReset(email: string): Promise<void> {
  const user = await db.users.findByEmail(email);
  if (!user) return; // Don't reveal if user exists
  
  const token = crypto.randomBytes(32).toString('hex');
  const expires = new Date(Date.now() + 3600000); // 1 hour
  
  await db.passwordResets.create({ userId: user.id, token, expires });
  await emailService.sendPasswordReset(email, token);
}
```

### 2. Testing Phase

```bash
# Check if testing is configured
ls jest.config.js
# ✓ Found

# Write tests
cat > tests/auth/passwordReset.test.ts << 'EOF'
describe('requestPasswordReset', () => {
  it('should create reset token for valid email', async () => {
    await requestPasswordReset('user@example.com');
    const reset = await db.passwordResets.findByUser('user@example.com');
    expect(reset).toBeDefined();
    expect(reset.token).toHaveLength(64);
  });

  it('should not reveal if email does not exist', async () => {
    await expect(
      requestPasswordReset('nonexistent@example.com')
    ).resolves.not.toThrow();
  });

  it('should set expiry to 1 hour', async () => {
    await requestPasswordReset('user@example.com');
    const reset = await db.passwordResets.findByUser('user@example.com');
    const oneHour = 3600000;
    const expiresIn = reset.expires.getTime() - Date.now();
    expect(expiresIn).toBeGreaterThan(oneHour - 1000);
    expect(expiresIn).toBeLessThan(oneHour + 1000);
  });
});
EOF

# Run tests
npm test
# ✓ All tests passed (3 passed)
```

### 3. Linting Phase

```bash
# Check if linter is configured
ls .eslintrc.js
# ✓ Found

# Run linter
npm run lint
# Output: 2 errors found

# Fix automatically
npm run lint:fix
# 1 error auto-fixed

# Fix remaining manually
# (add return type annotation)

# Re-run
npm run lint
# ✓ No errors
```

### 4. Security Phase

```bash
# Check if security tools are configured
which semgrep osv-scanner
# ✓ Both found

# Run security scans
semgrep --config=auto .
# Finding: Weak random token generation
# Fix: Use crypto.randomBytes (already done ✓)

osv-scanner --recursive .
# ✓ No vulnerabilities

npm audit
# ✓ No vulnerabilities
```

### 5. Completion

```
✓ Feature: Password reset implemented
✓ Tests: 3 tests written, all passing
✓ Linting: Clean lint report
✓ Security: No vulnerabilities found

Feature is complete and ready for review!
```

## Special Cases

### Bug Fixes

For bug fixes, follow the same process but:
1. Write regression test FIRST (reproduces bug)
2. Verify test fails
3. Fix the bug
4. Verify test now passes
5. Continue with linting and security

### Refactoring

For refactoring:
1. Ensure existing tests pass BEFORE refactoring
2. Refactor code
3. Verify all tests still pass (no behavior change)
4. Continue with linting and security

### Breaking Changes

If introducing breaking changes:
1. Complete normal flow
2. Add migration guide
3. Update version (major bump)
4. Document what breaks and how to migrate

## Time Estimates

Typical phase durations:

- **Implementation:** 60-80% of time
- **Testing:** 10-20% of time
- **Linting:** 2-5% of time
- **Security:** 2-5% of time

Total: Quality gates add ~15-30% overhead but catch issues early.

## Integration with CI/CD

All these quality gates should also run in CI:

```yaml
# .github/workflows/quality-gates.yml
name: Quality Gates

on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm install
      
      - name: Run tests
        run: npm test
      
      - name: Run linter
        run: npm run lint
      
      - name: Run security scans
        run: |
          semgrep --config=auto --error .
          osv-scanner --recursive .
          npm audit --audit-level=high
```

## Final Reminder

**This skill orchestrates the entire quality process.**

When implementing features:
1. Follow Phase 1-4 in order
2. Never skip a phase
3. Never proceed with failures
4. Only mark complete when ALL checkboxes pass

The goal is **quality over speed**. Better to take extra time and ensure correctness than to ship bugs, vulnerabilities, or technical debt.

## Related Skills

- `spec-creation` - Create specification documents (Phase 0)
- `testing-setup` - Set up test framework
- `testing-tdd` - Write and run tests
- `linting-setup` - Set up linter
- `linting-check` - Run linting
- `security-setup` - Set up security tools
- `security-check` - Run security scans

This skill references all of them in the proper order.
