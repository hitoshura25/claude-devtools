---
description: Create GitHub Actions workflows for automated Play Store deployment with staged rollouts
---

# Android Play Store Publishing

Generate GitHub Actions workflows for automated deployment to Google Play Store. Supports internal testing, beta tracks, and production with staged rollouts.

## What This Command Does

Complete CI/CD workflow generation:
- ✅ Internal testing (continuous deployment)
- ✅ Beta testing (alpha/beta tracks)
- ✅ Production (staged rollout with approval)
- ✅ Rollout management (increase/halt/complete)
- ✅ Version management scripts

## Usage

```bash
/devtools:android-playstore-publish
```

## Interactive Setup

The command will:
1. Ask which tracks to enable (internal/beta/production)
2. Ask about deployment triggers (push/tags/manual)
3. Ask about production approval requirement
4. Generate workflow files
5. Create deployment documentation
6. Provide setup instructions

## What Gets Created

**Workflows:**
- `.github/workflows/deploy-internal.yml` - Auto-deploy to internal
- `.github/workflows/deploy-beta.yml` - Manual beta deployment
- `.github/workflows/deploy-production.yml` - Production with approval
- `.github/workflows/manage-rollout.yml` - Rollout management

**Documentation:**
- `.github/workflows/README.md` - Workflow usage guide

**Scripts:**
- `scripts/increment-version.sh` - Version code management

## Prerequisites

- Play Console setup complete (`android-playstore-setup`)
- SERVICE_ACCOUNT_JSON in GitHub Secrets
- Signing secrets configured
- First manual upload to Play Console completed

## Deployment Flow

### Internal Testing (Automatic)
```
Push to main → Build → Deploy to Internal → Available in minutes
```

### Beta Testing (Manual)
```
Actions → Deploy to Beta → Select track → Select rollout → Deploy
```

### Production (Staged)
```
Tag v1.0.0 → Validate (E2E tests) → Approve → Deploy 5% → Monitor →
Increase to 20% → Monitor → Increase to 50% → Monitor → Complete 100%
```

## Workflow Features

**deploy-internal.yml:**
- Triggers: Push to main/develop
- Builds release AAB
- Deploys to internal track
- No approval required
- Fast feedback loop

**deploy-beta.yml:**
- Triggers: Manual dispatch
- Choose track (alpha/beta)
- Set rollout percentage
- Validation before deployment
- Artifact preservation

**deploy-production.yml:**
- Triggers: Version tags (v*) or manual
- E2E tests on release build
- Manual approval required
- Staged rollout (default 5%)
- Creates GitHub release
- Comprehensive monitoring

**manage-rollout.yml:**
- Triggers: Manual dispatch
- Actions: increase/halt/resume/complete
- Emergency halt capability
- Gradual rollout control

## GitHub Environment Setup

**Required for production:**

1. Repository → Settings → Environments
2. Create "production" environment
3. Add required reviewers
4. Save protection rules

This prevents accidental production deployments.

## Deployment Triggers

**Automatic:**
- Push to main → Internal testing
- Push tag v* → Production (after approval)

**Manual:**
- Beta: Actions → Deploy to Beta
- Production: Actions → Deploy to Production
- Rollout: Actions → Manage Production Rollout

## Staged Rollout Strategy

**Day 1:** 5% (initial, monitor closely)  
**Day 2-3:** 20% (if crash-free rate > 99%)  
**Day 4-5:** 50% (if stable)  
**Day 6-7:** 100% (complete rollout)

**Emergency:** Halt immediately if issues detected

## Version Management

**Increment version code:**
```bash
./scripts/increment-version.sh
git add app/build.gradle.kts
git commit -m "Bump version code"
git push
```

**Each deployment requires higher version code than previous**

## After Running This Command

**Setup GitHub Environment:**
```
1. Repository → Settings → Environments
2. Create "production"
3. Add required reviewers
4. Save
```

**First Deployment:**
```
1. Update release notes: distribution/whatsnew/en-US/whatsnew
2. Push to main → Auto-deploys to internal
3. Test on device
4. Deploy to beta: Actions → Deploy to Beta
5. Tag for production: git tag v1.0.0 && git push origin v1.0.0
6. Approve deployment
7. Monitor rollout
```

## Monitoring

**In Play Console:**
- Release → Production → Releases
- Check crash-free rate (target: > 99%)
- Review ANR rate
- Monitor user feedback

**In GitHub:**
- Actions tab → View workflow runs
- Check deployment summaries
- Download artifacts (mapping files)

## Security Features

- ✅ Keystore decoded only when needed
- ✅ Keystore deleted immediately after use
- ✅ Secrets never logged
- ✅ Environment protection for production
- ✅ Manual approval gates

## Troubleshooting

**"Version code already exists"**
→ Run `./scripts/increment-version.sh`

**"Service account permission denied"**
→ Verify permissions in Play Console → API access

**"First upload must be manual"**
→ Upload APK/AAB manually in Play Console first

**"Approval timeout"**
→ Approver must approve within timeout period
→ Re-run workflow

**"Missing release notes"**
→ Ensure distribution/whatsnew/en-US/whatsnew exists
→ Must be < 500 characters

## Best Practices

1. **Test in internal first** - Never skip
2. **Use staged rollouts** - Start small (5-10%)
3. **Monitor actively** - First 24 hours critical
4. **Keep mapping files** - Download from artifacts
5. **Tag releases** - Use semantic versioning

## Integration with Other Skills

**Requires:**
- android-release-build-setup
- android-e2e-testing-setup
- android-release-validation
- android-playstore-setup

**Enables:**
- Automated CI/CD deployment
- Complete release automation

## Skill Reference

This command uses the skill at:
`~/.claude/skills/user/devtools/android-playstore-publishing/SKILL.md`

## Related Commands

- `/devtools:android-playstore-setup` - Configure Play Console (prerequisite)
- `/devtools:android-release-validate` - Validate before deploy
- `/devtools:android-playstore-pipeline` - Complete setup (next)

## Example Session

```
User: /devtools:android-playstore-publish

Claude: I'll create GitHub Actions workflows for Play Store deployment.

Which tracks do you want to deploy to?
  ☑ Internal (continuous deployment)
  ☑ Beta (alpha/beta testing)
  ☑ Production (staged rollout)
→ All

Enable manual approval for production?
→ Yes (recommended)

What's your package name?
→ com.example.myapp

Creating workflows...
✓ deploy-internal.yml
✓ deploy-beta.yml
✓ deploy-production.yml
✓ manage-rollout.yml
✓ Deployment documentation
✓ Version management script

=== Setup Complete! ===

Next steps:
  1. Create production environment:
     Repository → Settings → Environments → New
     Name: production, Add reviewers, Save

  2. First deployment:
     git add .
     git commit -m "Add Play Store workflows"
     git push origin main
     → Auto-deploys to internal

  3. Production deployment:
     git tag v1.0.0
     git push origin v1.0.0
     → Requires approval, deploys with 5% rollout

Files created:
  - .github/workflows/deploy-internal.yml
  - .github/workflows/deploy-beta.yml
  - .github/workflows/deploy-production.yml
  - .github/workflows/manage-rollout.yml
  - .github/workflows/README.md
  - scripts/increment-version.sh
```

## Notes

- First Play Console upload MUST be manual
- Version code must increase with each upload
- ProGuard mapping files saved automatically
- Production requires approval via GitHub Environments
- Use staged rollouts to minimize risk
