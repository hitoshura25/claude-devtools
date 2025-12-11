---
description: Create GitHub Actions workflows for automated Play Store deployment with staged rollouts
---

# Android Play Store Publishing

Generates GitHub Actions workflows for automated deployment to Google Play Store with staged rollouts.

## Skill Reference

**Read and execute the skill at:**
`~/claude-devtools/skills/android-playstore-publishing/SKILL.md`

⚠️ **Read the entire skill file before executing.** Follow all steps exactly.

## Completion Criteria

Do NOT mark complete unless ALL are verified:

- [ ] Workflow files created: `.github/workflows/deploy-*.yml`
- [ ] All workflow YAML files are valid: `yamllint .github/workflows/`
- [ ] Version management script created: `scripts/increment-version.sh`
- [ ] Deployment documentation created
- [ ] GitHub "production" environment created with reviewers
- [ ] First manual upload to Play Console completed

## Quick Reference

**Inputs:** Play Console setup complete, SERVICE_ACCOUNT_JSON in GitHub Secrets
**Outputs:** 4 GitHub Actions workflows, version script, deployment documentation
**Verify:** `yamllint .github/workflows/deploy-*.yml`

## Prerequisites

- Run `/devtools:android-playstore-setup` first
- SERVICE_ACCOUNT_JSON in GitHub Secrets
- Signing secrets configured
- First manual upload to Play Console required

## Related Commands

- `/devtools:android-playstore-setup` - Required before this
- `/devtools:android-release-validate` - Validate before deploy
- `/devtools:android-playstore-pipeline` - Complete setup guide
