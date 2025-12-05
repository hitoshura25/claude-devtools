---
description: Create specification document for a feature (user)
---

Read and follow the skill at ~/.claude/skills/user/devtools/spec-creation/SKILL.md to create a specification for:

$ARGUMENTS

This command creates a specification document in the `./specs/` folder without implementing the feature.

The AI agent will:
1. Analyze the feature requirements
2. Explore the codebase if needed
3. Choose appropriate detail level (Level 1, 2, or 3)
4. Create the spec file with timestamp: `./specs/YYYY-MM-DD-feature-name.md`
5. Confirm with you

Use this when you want to:
- Plan a feature before implementing it
- Document architectural decisions
- Enable session resumption for complex work
- Create a roadmap for multi-session features

After creating the spec, you can implement it using:
```
/devtools:develop "Implement the feature (following existing spec)"
```
