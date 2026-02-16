# GitHub Actions CI/CD Workflows

Complete CI/CD setup for npm monorepo with Changesets.

## Workflow Overview

```
Feature PR → CI (test/lint/build)
    ↓
Merge to main → CI creates "Version Packages" PR
    ↓
Merge Version PR → CI publishes to npm
```

## Main CI Workflow

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build

      - name: Lint
        run: pnpm lint

      - name: Test
        run: pnpm test

  release:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [test]
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: main

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      # Check for new packages needing NPM_TOKEN
      - name: Check package registry status
        id: check-packages
        run: |
          PACKAGES=$(pnpm list -r --depth -1 --json 2>/dev/null | jq -r '.[] | select(.private != true) | .name')
          NEW=""
          for PKG in $PACKAGES; do
            if [ -n "$PKG" ] && ! npm view "$PKG" version &>/dev/null; then
              NEW="$NEW $PKG"
            fi
          done
          if [ -n "$NEW" ]; then
            echo "has_new_packages=true" >> $GITHUB_OUTPUT
          else
            echo "has_new_packages=false" >> $GITHUB_OUTPUT
          fi

      - name: Configure npm for new packages
        if: steps.check-packages.outputs.has_new_packages == 'true'
        run: echo "//registry.npmjs.org/:_authToken=${NPM_PUBLISH_TOKEN}" > ~/.npmrc
        env:
          NPM_PUBLISH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Create Release PR or Publish
        id: changeset
        uses: changesets/action@v1
        with:
          version: pnpm changeset version
          publish: pnpm release
          commit: "Version Packages"
          title: "Version Packages"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # Optional: Auto-merge Version PR
      - name: Enable auto-merge
        if: steps.changeset.outputs.pullRequestNumber != ''
        run: gh pr merge --auto --squash "${{ steps.changeset.outputs.pullRequestNumber }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Using GitHub App for PRs

For better security, use a GitHub App instead of `GITHUB_TOKEN`:

```yaml
- name: Generate token
  id: generate-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.RELEASE_BOT_APP_ID }}
    private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

- uses: changesets/action@v1
  env:
    GITHUB_TOKEN: ${{ steps.generate-token.outputs.token }}
```

### Creating a GitHub App

1. Go to GitHub → Settings → Developer settings → GitHub Apps
2. Create new app with permissions:
   - Contents: Read and write
   - Pull requests: Read and write
   - Metadata: Read-only
3. Generate private key
4. Add to repository secrets:
   - `RELEASE_BOT_APP_ID`
   - `RELEASE_BOT_PRIVATE_KEY`

## Auto-Approve Workflow (Optional)

Auto-approve Version Packages PRs:

### .github/workflows/auto-approve.yml

```yaml
name: Auto-approve Version Packages

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    if: |
      github.event.pull_request.user.login == 'github-actions[bot]' &&
      github.event.pull_request.title == 'Version Packages'
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Auto-approve
        run: gh pr review "${{ github.event.pull_request.number }}" --approve
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Required Secrets

| Secret | Purpose | Required |
|--------|---------|----------|
| `NPM_PUBLISH_TOKEN` | First publish of new packages | Yes |
| `RELEASE_BOT_APP_ID` | GitHub App for PRs | Optional |
| `RELEASE_BOT_PRIVATE_KEY` | GitHub App for PRs | Optional |

## Branch Protection

Recommended settings for `main`:

- ✅ Require status checks (test job)
- ✅ Require branches to be up to date
- ✅ Require pull request reviews
- ✅ Allow auto-merge

## Workflow Outputs

The `changesets/action` provides outputs:

```yaml
- uses: changesets/action@v1
  id: changeset

# Available outputs:
# steps.changeset.outputs.published - "true" if packages were published
# steps.changeset.outputs.publishedPackages - JSON array of published packages
# steps.changeset.outputs.hasChangesets - "true" if pending changesets exist
# steps.changeset.outputs.pullRequestNumber - PR number if created
```

## Debugging

### View Workflow Logs

1. Go to repository → Actions
2. Click failed workflow
3. Expand failed step

### Common Issues

**"Nothing to publish"**
- No changesets exist
- Changesets already consumed by Version PR

**"Permission denied"**
- Check `permissions` block in workflow
- Verify secrets exist

**"Version Packages PR not created"**
- Verify `GITHUB_TOKEN` has write permissions
- Check branch protection rules
