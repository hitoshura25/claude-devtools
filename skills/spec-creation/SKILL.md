# Specification Creation Skill

Create detailed specification documents for features to ensure context retention across sessions.

## Purpose

This skill creates specification documents in the project's `./specs/` folder to:
- **Preserve context** across Claude Code sessions
- **Document implementation plans** before coding begins
- **Enable session resumption** with full context for new AI agents
- **Track architectural decisions** and rationale

## When to Create a Spec

The AI agent should **intelligently decide** when to create a spec based on:

### Always Create Spec For:
- **Complex features** (multiple files, multiple phases, >50 lines of code)
- **Architectural changes** (new patterns, refactoring, breaking changes)
- **Cross-cutting concerns** (affects multiple modules/layers)
- **Features requiring research** (need to explore codebase first)
- **Multi-session work** (likely to take >30 minutes)

### Usually Create Spec For:
- **New API endpoints** or services
- **Database schema changes**
- **New authentication/authorization logic**
- **Integration with external services**
- **Performance optimizations** (need baseline measurements)

### May Skip Spec For:
- **Simple bug fixes** (single file, clear fix)
- **Trivial changes** (<20 lines, single function)
- **Documentation updates**
- **Simple refactoring** (rename, move files)

### Always Honor User Preference:
- **User explicitly requests spec**: Always create, regardless of complexity
- **User explicitly declines spec**: Never create, even for complex features
- **User doesn't specify**: AI decides based on complexity

## Process

### Step 1: Assess Complexity

Analyze the feature request:

```
Questions to ask:
- How many files will be affected?
- How many distinct phases/steps are needed?
- Are there architectural decisions to make?
- Will this require codebase research?
- Is this likely to span multiple sessions?
- Are there multiple valid approaches?
```

**Decision criteria:**
```
High complexity (create spec):
  - >3 files affected OR
  - >2 architectural decisions OR
  - Requires codebase exploration OR
  - Multiple implementation approaches

Low complexity (skip spec):
  - 1-2 files affected AND
  - Clear implementation path AND
  - No architectural decisions AND
  - <50 lines of code
```

### Step 2: Determine Spec Detail Level

Based on complexity, choose appropriate detail level:

#### Level 1: High-Level Plan (Simple Features)
```markdown
# Feature: [Name]

## Goal
[What we're building and why]

## Implementation Steps
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Files to Modify
- `path/to/file1.ts`
- `path/to/file2.ts`

## Testing Approach
[Brief testing strategy]

## Quality Gates
- [ ] Tests written and passing
- [ ] Linting clean
- [ ] Security scan passed
```

#### Level 2: Detailed Implementation Plan (Moderate Features - DEFAULT)
```markdown
# Feature: [Name]

## Overview
[What we're building, why, and high-level approach]

## Technical Approach

### Architecture Decisions
- **Decision 1**: [Choice] - [Rationale]
- **Decision 2**: [Choice] - [Rationale]

### File Changes
#### New Files
- `path/to/new_file.ts` - [Purpose]

#### Modified Files
- `path/to/existing.ts` - [What changes]

### Data Models
```typescript
interface User {
  id: string;
  email: string;
}
```

### API Contracts
```typescript
POST /api/auth/login
Request: { email: string, password: string }
Response: { token: string, user: User }
```

## Implementation Plan

### Phase 1: Core Implementation
1. [Detailed step]
2. [Detailed step]

### Phase 2: Testing
- Unit tests for [components]
- Integration tests for [flows]
- Edge cases: [list]

### Phase 3: Quality Gates
- Linting checks
- Security scan focus areas: [authentication, input validation, etc.]

## Acceptance Criteria
- [ ] Feature works as specified
- [ ] All tests pass
- [ ] No lint errors
- [ ] No security vulnerabilities
- [ ] Documentation updated

## Session Resumption Context
If resuming this work in a new session:
1. Current state: [What's done]
2. Next steps: [What's remaining]
3. Key context: [Important decisions/discoveries]
```

#### Level 3: Complete Specification (Complex Features)
```markdown
# Feature Specification: [Name]

## Overview

### Objective
[Detailed description of what and why]

### Stakeholders
- User: [Who benefits]
- Technical: [What systems affected]

### Success Metrics
- [Metric 1]
- [Metric 2]

## Requirements

### Functional Requirements
1. [Requirement with acceptance criteria]
2. [Requirement with acceptance criteria]

### Non-Functional Requirements
- Performance: [Targets]
- Security: [Requirements]
- Scalability: [Considerations]

## Technical Design

### Architecture Decisions

#### Decision 1: [Topic]
- **Options Considered**: [A, B, C]
- **Chosen**: [B]
- **Rationale**: [Why B over A and C]
- **Trade-offs**: [What we gain/lose]

### System Architecture
```
[Diagram or description of components]
```

### Data Models
```typescript
// Detailed type definitions with comments
interface User {
  id: string;           // UUID v4
  email: string;        // Validated, lowercase
  passwordHash: string; // bcrypt, 10 rounds
  createdAt: Date;
}
```

### API Specification
```typescript
/**
 * Authenticate user and return JWT token
 * @throws 401 if credentials invalid
 * @throws 429 if rate limit exceeded
 */
POST /api/auth/login
Request: {
  email: string;    // Required, validated
  password: string; // Required, min 8 chars
}
Response: {
  token: string;    // JWT, expires 24h
  user: User;       // User object without password
}
```

### Database Schema
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Security Considerations
- **Authentication**: JWT with 24h expiry
- **Password storage**: bcrypt with 10 rounds
- **Rate limiting**: 5 attempts per 15 minutes
- **Input validation**: Email format, password strength
- **XSS prevention**: Sanitize all inputs
- **SQL injection**: Use parameterized queries

## Implementation Plan

### Phase 0: Research & Setup
1. [Research existing patterns]
2. [Setup dependencies]
3. [Create migrations]

### Phase 1: Core Implementation
1. [Step-by-step implementation]
2. [Each step with specific file changes]

### Phase 2: Testing Strategy

#### Unit Tests
- `authenticateUser()` - valid credentials
- `authenticateUser()` - invalid credentials
- `authenticateUser()` - rate limiting
- `hashPassword()` - proper bcrypt
- `validateEmail()` - valid/invalid formats

#### Integration Tests
- Full login flow (POST /api/auth/login)
- Token validation
- Rate limiting enforcement

#### Edge Cases
- Empty credentials
- SQL injection attempts
- Very long passwords (>1000 chars)
- Concurrent login attempts

### Phase 3: Quality Gates

#### Linting Focus
- Consistent error handling
- Proper type annotations
- No unused variables
- Async/await usage

#### Security Scan Focus
- Hardcoded secrets
- SQL injection vulnerabilities
- XSS vulnerabilities
- Weak cryptography
- Dependency vulnerabilities

## File Changes

### New Files
```
src/auth/
  ├── login.ts           - Login endpoint handler
  ├── passwordHash.ts    - Password hashing utilities
  └── validation.ts      - Input validation

tests/auth/
  ├── login.test.ts      - Login tests
  └── validation.test.ts - Validation tests
```

### Modified Files
```
src/routes.ts          - Add /api/auth/login route
src/middleware/auth.ts - Update JWT validation
database/migrations/   - Add 001_create_users.sql
```

## Dependencies

### New Dependencies
```json
{
  "bcrypt": "^5.1.0",        // Password hashing
  "jsonwebtoken": "^9.0.0",  // JWT tokens
  "express-rate-limit": "^7.0.0"  // Rate limiting
}
```

### Security Review
- bcrypt: Well-maintained, no known CVEs
- jsonwebtoken: Trusted, widely used
- express-rate-limit: Actively maintained

## Rollback Plan

If issues arise:
1. Remove new routes from `routes.ts`
2. Rollback database migration
3. Remove auth middleware changes
4. Remove new files in `src/auth/`

## Documentation Updates

- [ ] Update API documentation with `/api/auth/login`
- [ ] Add authentication guide to README
- [ ] Document rate limiting behavior
- [ ] Add migration guide if breaking changes

## Session Resumption Context

### Current State
- [What's implemented]
- [What tests are written]
- [What's been verified]

### Next Steps
1. [Immediate next action]
2. [Following actions]

### Key Discoveries
- [Important findings during implementation]
- [Deviations from original plan]
- [Blockers or challenges]

### Open Questions
- [Questions that need answering]
- [Decisions that need making]

## Acceptance Criteria

### Functional
- [ ] User can log in with valid credentials
- [ ] Invalid credentials return 401
- [ ] Rate limiting prevents brute force
- [ ] JWT token is returned on success
- [ ] Token can be used for authenticated requests

### Quality Gates
- [ ] All unit tests pass (>90% coverage)
- [ ] All integration tests pass
- [ ] Linting clean (0 errors)
- [ ] Security scan passed (0 critical/high)
- [ ] Documentation complete

### Performance
- [ ] Login completes in <500ms (p95)
- [ ] Password hashing uses bcrypt (10 rounds)
- [ ] Rate limiting active and tested
```

## Creating the Spec File

### Step 3: Generate Filename

Use a clear, descriptive filename with timestamp:

```bash
# Format: YYYY-MM-DD-descriptive-name.md
# Examples:
specs/2024-12-05-user-authentication.md
specs/2024-12-05-password-reset.md
specs/2024-12-05-api-refactoring.md
```

### Step 4: Choose Template Based on Complexity

```typescript
// Pseudocode for template selection
if (userSpecifiedDetail) {
  template = userSpecifiedDetail;
} else if (highComplexity || multiSession || architecturalDecisions) {
  template = "Level 3: Complete Specification";
} else if (moderateComplexity || multipleFiles || needsDetailedPlan) {
  template = "Level 2: Detailed Implementation Plan"; // DEFAULT
} else {
  template = "Level 1: High-Level Plan";
}
```

### Step 5: Populate Spec File

1. **Understand the requirement** thoroughly
2. **Explore codebase** if needed (existing patterns, files, architecture)
3. **Make architectural decisions** with rationale
4. **Fill in template** with specific details
5. **Write to file** in `./specs/` directory

### Step 6: Confirm with User

After creating spec:
```
✓ Created specification: specs/2024-12-05-user-authentication.md
  Detail level: Level 2 (Detailed Implementation Plan)
  Rationale: Feature affects 5 files, includes authentication logic, needs session context

Would you like me to:
1. Proceed with implementation following this spec
2. Review/modify the spec first
3. Cancel and skip the spec
```

## Example: Decision Flow

```
User: "/devtools:develop Add user login"

AI Agent Analysis:
- Complexity: High (new authentication, multiple files, security critical)
- Files affected: 5+ (routes, middleware, models, tests)
- Architectural decisions: JWT vs sessions, password hashing
- User preference: Not specified

Decision: CREATE SPEC (Level 2 - Detailed Implementation Plan)
Rationale: Complex feature with security implications, needs documentation

AI Agent: "I'm creating a specification for this feature to ensure we cover
all security and architectural considerations. This will help with session
resumption if needed."

[Creates specs/2024-12-05-user-login.md with Level 2 detail]

AI Agent: "✓ Created specification: specs/2024-12-05-user-login.md
Would you like me to proceed with implementation?"
```

## Integration with Feature Development

When integrated into the `feature-development` skill:

```
Phase 0: Specification (CONDITIONAL)
   ↓ (if spec needed)
   Create spec in ./specs/
   ↓
Phase 1: Implement Feature
   ↓
Phase 2: Testing Phase
   ↓
Phase 3: Linting Phase
   ↓
Phase 4: Security Phase
   ↓
Phase 5: Update Spec (mark complete)
   ↓
Completion ✓
```

## Spec File Lifecycle

### During Implementation
- **Reference**: Check spec for next steps
- **Update**: Add discoveries, decisions, blockers
- **Track progress**: Mark checkboxes as complete

### After Completion
- **Final update**: Mark all checkboxes complete
- **Add outcomes**: What was built, what changed from plan
- **Archive**: Keep for historical reference

### On Session Resumption
- **Read spec**: Understand context and current state
- **Continue**: Pick up from "Next Steps"
- **Update**: Mark new progress

## User Preference Handling

### Explicit Spec Request
```
User: "/devtools:develop Add login (create spec)"
AI: Always creates spec, regardless of complexity
```

### Explicit Spec Decline
```
User: "/devtools:develop Add login (no spec)"
AI: Skips spec, proceeds directly to implementation
```

### No Preference (AI Decides)
```
User: "/devtools:develop Add login"
AI: Analyzes complexity, decides based on criteria
    If creating spec: Explains rationale
    If skipping: Proceeds silently
```

### Detail Level Specification
```
User: "/devtools:develop Add login (detailed spec)"
AI: Creates Level 3 (Complete Specification)

User: "/devtools:develop Add login (simple spec)"
AI: Creates Level 1 (High-Level Plan)

User: "/devtools:develop Add login"
AI: Chooses appropriate level (usually Level 2)
```

## Standalone Usage

When used independently (via `/devtools:spec` command):

```
User: "/devtools:spec Create spec for user authentication feature"

AI Agent:
1. Asks clarifying questions if needed
2. Explores codebase for context
3. Creates appropriate level spec
4. Confirms with user
5. Does NOT implement (spec only)
```

## Best Practices

### Spec Creation
- **Be specific**: Use concrete examples, not abstractions
- **Include rationale**: Explain WHY decisions were made
- **Document trade-offs**: What alternatives were considered
- **Keep updated**: Update spec as implementation progresses
- **Use checkboxes**: Track progress visually

### Spec Usage
- **Read before resuming**: Always read spec when resuming work
- **Follow the plan**: Spec provides the roadmap
- **Update discoveries**: Add new information as you learn
- **Mark progress**: Check off completed items
- **Final review**: Ensure all acceptance criteria met

### Spec Management
- **One spec per feature**: Don't combine unrelated features
- **Descriptive names**: Use clear, searchable filenames
- **Include dates**: Timestamp helps track project evolution
- **Archive old specs**: Keep for reference, but mark as completed
- **Version control**: Commit specs with code changes

## Error Handling

### Specs Folder Missing
```bash
# Create ./specs/ if it doesn't exist
mkdir -p ./specs
```

### Spec Already Exists
```bash
# Check if file exists
if [ -f "specs/2024-12-05-user-login.md" ]; then
  # Ask user: overwrite, rename, or cancel
fi
```

### User Changes Mind
```
User: "Actually, skip the spec"
AI: Acknowledges, proceeds without spec
```

## Related Skills

- `feature-development` - Uses this skill in Phase 0
- `testing-tdd` - References spec for test cases
- `security-check` - References spec for security considerations

## Completion Criteria

Spec creation is complete when:
- [ ] Spec file created in `./specs/` directory
- [ ] Appropriate detail level chosen
- [ ] All relevant sections filled in
- [ ] User confirmed or auto-proceeding
- [ ] Spec is readable and actionable for new AI agent

## Final Notes

**Goal**: Make it easy to resume work across sessions

A good spec should allow a **completely new AI agent** (with no prior context) to:
1. Understand what needs to be built
2. Know what architectural decisions were made and why
3. See what's already completed
4. Pick up exactly where the previous session left off
5. Complete the feature following the same plan

**Keep specs actionable, not academic.**
