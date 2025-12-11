# Claude DevTools Architecture

This document describes the architecture and design principles of the claude-devtools system.

## Overview

claude-devtools follows a three-tier architecture designed for **reliability, maintainability, and progressive disclosure**:

```
┌─────────────────────────────────────────────────────────────┐
│                     User Request                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Command (Pass-through)                    │
│  - Points to skill                                          │
│  - Lists completion criteria                                │
│  - No implementation details                                │
│  - Reliability: ~95%                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Skill (Single-Purpose)                    │
│  - One focused action (2-3 steps max)                       │
│  - Clear inputs/outputs                                     │
│  - Verification command                                     │
│  - No orchestration of other skills                         │
│  - Reliability: ~95% per skill                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              MCP Tool (Orchestration - Future)               │
│  - Combines multiple skills                                 │
│  - Deterministic execution                                  │
│  - Progress reporting                                       │
│  - Reliability: ~95%                                        │
└─────────────────────────────────────────────────────────────┘
```

## Design Principles

### 1. Commands Are Thin Pass-Throughs

**Problem:** Duplicating skill content in commands creates maintenance burden and potential drift.

**Solution:** Commands reference skills and provide:
- Skill file location
- Brief description (1-2 sentences)
- Completion criteria checkboxes
- Quick reference (inputs/outputs/verify command)
- NO implementation details

**Example:**
```markdown
## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-keystore-generation/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:
- [ ] `keystores/production-release.jks` exists
- [ ] `keystores/local-dev-release.jks` exists
```

### 2. Skills Are Single-Purpose

**Problem:** Multi-step skills have 40-60% reliability because agents skip steps.

**Root Cause:**
```
Agent Decision Points × Steps = Failure Probability

Single-step skill:  1 decision  → ~95% success
5-step skill:       5 decisions → ~60% success (0.95^5 ≈ 0.77, with attention drift ~60%)
10-step skill:      10 decisions → ~40% success
```

**Solution:** Each skill does ONE thing with 2-3 steps maximum:
- Clear, focused action
- Single verification command
- No calling other skills (orchestration happens elsewhere)

**Example - Atomic Skill:**
```markdown
---
name: android-keystore-generation
description: Generate production and local development keystores
verify: "ls keystores/*.jks && cat keystores/KEYSTORE_INFO.txt"
---

## Process

### Step 1: Create Directory
### Step 2: Generate Production Keystore
### Step 3: Generate Local Keystore

## Verification

`ls keystores/*.jks`
```

### 3. Orchestration Through Document-Only or MCP Tools

**Problem:** Skills that orchestrate other skills have poor reliability (~40-60%).

**Current Solution:** Document-only orchestration
- Guide lists skills to run in order
- Each skill verified before continuing
- User manually ensures completion
- Reliability: ~95% per skill

**Example:**
```markdown
## Step 1: Release Build Setup

`/devtools:android-release-setup`

**Verify before continuing:**
```bash
./gradlew assembleRelease
```

---

## Step 2: E2E Testing
...
```

**Future Solution:** MCP tool orchestration
- Deterministic execution of multiple skills
- Progress reporting
- Automatic verification
- Target reliability: ~95%

## Architecture Tiers

### Tier 1: Commands (Entry Points)

**Location:** `commands/devtools/*.md`

**Purpose:** User-facing entry points that:
- Invoke slash command system
- Reference appropriate skill
- Provide completion criteria
- Give quick reference

**Characteristics:**
- Under 50 lines
- No implementation details
- Clear completion checkboxes
- Single verification command

**Examples:**
- `/devtools:android-release-setup`
- `/devtools:test`
- `/devtools:lint`

### Tier 2: Skills (Implementation)

**Location:** `skills/*/SKILL.md`

**Types:**

#### A. Atomic Skills (Single-Purpose)
- Do ONE thing
- 2-3 steps maximum
- No orchestration
- ~95% reliability

**Examples:**
- `android-keystore-generation` - Generate keystores only
- `android-proguard-setup` - Configure ProGuard only
- `android-signing-config` - Setup signing only

#### B. Orchestrator Skills (Reference Documents)
- Reference 2-5 atomic skills
- Provide verification between steps
- Clear completion criteria
- User ensures manual progression

**Examples:**
- `android-release-build-setup` - References 3 atomic skills
- `android-e2e-testing-setup` - References 3 atomic skills
- `android-playstore-setup` - References 3 atomic skills

### Tier 3: MCP Tools (Future)

**Purpose:** Deterministic orchestration with high reliability

**Planned:**
- `@hitoshura25/mcp-android` - Android deployment pipeline
- Multi-skill execution with automatic verification
- Progress tracking and error recovery

## Skill Decomposition

### Example: Android Release Build Setup

**Before (Monolithic):**
```
android-release-build-setup (557 lines)
├── Step 1-2: Generate keystores
├── Step 3-4: Configure ProGuard
├── Step 5-7: Setup signing
└── Step 8-9: Verification
Reliability: ~40-60%
```

**After (Decomposed):**
```
android-release-build-setup (194 lines, orchestrator)
├── → android-keystore-generation (145 lines)
│   └── Reliability: ~95%
├── → android-proguard-setup (130 lines)
│   └── Reliability: ~95%
└── → android-signing-config (165 lines)
    └── Reliability: ~95%

Overall: Each skill ~95% reliable
User verifies each before continuing
```

## Skill Template Structure

### Atomic Skill Template

```markdown
---
name: skill-name
description: Single-sentence description of ONE action
category: category
version: 1.0.0
inputs:
  - input1: Description
outputs:
  - output1: Location
verify: "single command to verify success"
---

# Skill Name

One paragraph describing what this skill does - single action only.

## Prerequisites

- Prerequisite 1
- Prerequisite 2

## Process

### Step 1: [Action]
[Details and commands]

### Step 2: [Action] (if needed)
[Keep to 2-3 steps maximum]

## Verification

**MANDATORY:** `single verification command`

**Expected output:** What success looks like

## Completion Criteria

- [ ] Specific verifiable criterion
- [ ] Specific verifiable criterion
```

### Orchestrator Skill Template

```markdown
---
name: orchestrator-skill-name
description: Orchestrates X atomic skills
version: 2.0.0
---

# Orchestrator Skill Name

This skill orchestrates [complete action] by running [N] atomic skills in sequence.

## Process

### Step 1: [Atomic Skill 1]

Follow the skill at: `~/claude-devtools/skills/atomic-skill-1/SKILL.md`

**What it does:** Brief description

**Verify before continuing:**
```bash
verification command
```

---

### Step 2: [Atomic Skill 2]
...

## Final Verification

Complete verification commands after all skills complete.
```

## File Organization

```
claude-devtools/
├── commands/
│   └── devtools/
│       ├── android-release-setup.md      # Pass-through command
│       ├── test.md                       # Pass-through command
│       └── ...
├── skills/
│   ├── android-keystore-generation/
│   │   └── SKILL.md                      # Atomic skill
│   ├── android-proguard-setup/
│   │   └── SKILL.md                      # Atomic skill
│   ├── android-release-build-setup/
│   │   └── SKILL.md                      # Orchestrator skill
│   └── ...
├── specs/
│   └── skills-refactoring-spec.md        # This refactoring spec
├── README.md                              # Project overview
├── INDEX.md                               # Skill catalog
└── ARCHITECTURE.md                        # This document
```

## Reliability Analysis

### Before Refactoring

| Type | Steps | Reliability | Issue |
|------|-------|-------------|-------|
| Monolithic Skill | 10 steps | ~40% | Too many decision points |
| Command Duplication | N/A | N/A | Maintenance burden |
| Mixed Orchestration | 5-7 steps | ~60% | Agent skips steps |

### After Refactoring

| Type | Steps | Reliability | Benefit |
|------|-------|-------------|---------|
| Atomic Skill | 2-3 steps | ~95% | Single focused action |
| Pass-Through Command | 0 steps | ~100% | Just references skill |
| Document Orchestration | N/A | ~95% per skill | User verifies each |

## Migration Path

### Phase 1: Command Refactoring ✅
- Convert commands to thin pass-throughs
- Remove implementation details
- Add completion criteria

### Phase 2: Bug Fixes ✅
- Fix critical issues (PKCS12 passwords)
- Update security practices

### Phase 3: Skill Decomposition ✅
- Create atomic skills
- Refactor monolithic skills to orchestrators
- Maintain backward compatibility

### Phase 4: Documentation ✅
- Update README.md
- Update INDEX.md
- Create ARCHITECTURE.md (this document)

### Phase 5: MCP Tools (Future)
- Implement deterministic orchestration
- Provide automatic verification
- Enable complex multi-skill workflows

## Best Practices

### For Command Authors

1. **Keep commands under 50 lines**
2. **Reference skill, don't duplicate**
3. **Provide completion criteria**
4. **Include quick reference**
5. **No implementation details**

### For Skill Authors

1. **Do ONE thing** (single-purpose)
2. **Keep to 2-3 steps maximum**
3. **Include single verification command**
4. **Clear inputs/outputs**
5. **Don't orchestrate other skills**
6. **If skill is complex, decompose it**

### For Orchestrator Skills

1. **Reference atomic skills only**
2. **Provide verification between steps**
3. **Clear step-by-step progression**
4. **Comprehensive final verification**
5. **Version as 2.0.0 (indicates orchestrator)**

## Validation Criteria

### For Commands

- [ ] Under 50 lines
- [ ] References skill file path explicitly
- [ ] Has completion criteria checkboxes
- [ ] Has single verification command
- [ ] No implementation details duplicated

### For Atomic Skills

- [ ] Does ONE thing
- [ ] Has 3 or fewer steps
- [ ] Has single verification command
- [ ] Completable in under 5 minutes
- [ ] Has clear inputs/outputs table
- [ ] No orchestration of other skills

### For Orchestrator Skills

- [ ] References only atomic skills
- [ ] Has verification between each step
- [ ] Has comprehensive final verification
- [ ] Versioned as 2.0.0 or higher
- [ ] Clear step-by-step progression

## Conclusion

This architecture prioritizes:
- **Reliability:** ~95% per atomic skill vs ~40-60% for monolithic
- **Maintainability:** Single source of truth (skill files)
- **Clarity:** Each skill has one clear purpose
- **Progressive Disclosure:** Commands are simple, skills provide detail
- **Future-Ready:** Designed for MCP tool orchestration

The refactoring maintains backward compatibility while dramatically improving reliability and reducing maintenance burden.
