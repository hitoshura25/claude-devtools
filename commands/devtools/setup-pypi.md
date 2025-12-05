---
description: Setup automated PyPI publishing with GitHub Actions
---

Read and follow ~/.claude/skills/user/devtools/pypi-publishing/SKILL.md to set up automated PyPI publishing with GitHub Actions.

This includes:
- Gathering project information (package name, author, etc.)
- Creating pyproject.toml and setup.py if needed
- Generating 3 GitHub Actions workflows (release, PR testing, reusable)
- Creating version calculation script
- Providing instructions for PyPI Trusted Publishers setup

The skill uses templates and will perform simple variable substitution to generate all necessary files.
