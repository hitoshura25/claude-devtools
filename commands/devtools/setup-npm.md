---
description: Setup automated npm publishing with GitHub Actions
---

Read and follow ~/.claude/skills/user/devtools/npm-publishing/SKILL.md to set up automated npm publishing with GitHub Actions.

This includes:
- Reading package.json for package information
- Detecting monorepo structure if applicable
- Generating GitHub Actions workflow
- Providing instructions for NPM_TOKEN setup

Features:
- Automatic publishing on push to main
- RC (release candidate) versions for pull requests
- Monorepo support with path-based triggers
- Automatic version bumping
