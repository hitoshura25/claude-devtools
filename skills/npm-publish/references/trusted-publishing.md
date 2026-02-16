# NPM Trusted Publishing with OIDC

Secure, token-less publishing from GitHub Actions using OpenID Connect.

## Benefits

- ✅ No long-lived tokens to manage or rotate
- ✅ Short-lived, workflow-specific credentials
- ✅ Automatic provenance attestation
- ✅ Supply chain security verification

## How It Works

```
GitHub Actions → Request OIDC token → GitHub OIDC Provider
                                              ↓
                                        Return signed token
                                              ↓
GitHub Actions → Publish with token → npm Registry
                                              ↓
npm Registry → Verify signature → GitHub OIDC Provider
                                              ↓
                                        Token valid ✓
                                              ↓
npm Registry → Publish with provenance
```

## Self-Bootstrapping Workflow

The recommended approach handles both new and existing packages:

### For New Packages (First Publish)
1. Workflow detects package doesn't exist on npm
2. Uses `NPM_PUBLISH_TOKEN` for initial publish
3. Logs npm settings URL
4. **Action Required:** Configure OIDC on npmjs.com

### For Existing Packages
1. Workflow detects package exists
2. Uses OIDC if configured
3. Falls back to `NPM_PUBLISH_TOKEN` if not

### After OIDC Configuration
1. All publishes use OIDC automatically
2. No token needed
3. Provenance generated

## Setup Instructions

### Step 1: Create NPM Automation Token

1. Go to npmjs.com → Account → Access Tokens
2. Generate **Automation** token (not Granular)
3. Add to GitHub repository secrets as `NPM_PUBLISH_TOKEN`

### Step 2: Configure CI Workflow

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write  # Required for OIDC
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      # Check if any packages are new (need NPM_TOKEN)
      - name: Check package registry status
        id: check-packages
        run: |
          PACKAGES=$(pnpm list -r --depth -1 --json | jq -r '.[] | select(.private != true) | .name')
          NEW_PACKAGES=""
          for PKG in $PACKAGES; do
            if ! npm view "$PKG" version &>/dev/null; then
              NEW_PACKAGES="$NEW_PACKAGES $PKG"
            fi
          done
          if [ -n "$NEW_PACKAGES" ]; then
            echo "has_new_packages=true" >> $GITHUB_OUTPUT
          else
            echo "has_new_packages=false" >> $GITHUB_OUTPUT
          fi

      # Configure npm auth for new packages
      - name: Configure npm authentication
        if: steps.check-packages.outputs.has_new_packages == 'true'
        run: |
          echo "//registry.npmjs.org/:_authToken=${NPM_PUBLISH_TOKEN}" > ~/.npmrc
        env:
          NPM_PUBLISH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: pnpm test

      - uses: changesets/action@v1
        with:
          version: pnpm changeset version
          publish: pnpm release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Step 3: First Publish

Merge a changeset to main. CI will:
1. Detect new package
2. Use NPM_TOKEN
3. Publish successfully

### Step 4: Configure OIDC on npmjs.com

After first publish:

1. Go to `https://www.npmjs.com/package/@scope/package-name/settings`
2. Scroll to **Trusted Publishers**
3. Click **Add a publisher**
4. Select **GitHub Actions**
5. Fill in:

| Field | Value |
|-------|-------|
| Organization or Username | `your-github-username` |
| Repository | `your-repo-name` |
| Workflow filename | `ci.yml` |
| Environment | *(leave empty)* |

6. Click **Add trusted publisher**

### Step 5: Verify OIDC

Next publish will:
1. Use OIDC automatically
2. Generate provenance

Verify:
```bash
npm view @scope/package-name --json | jq '.provenance'
```

## Package Configuration

Required fields in package.json for OIDC:

```json
{
  "name": "@scope/package-name",
  "repository": {
    "type": "git",
    "url": "https://github.com/user/repo"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

## Verification Script

Check OIDC status for all packages:

```bash
#!/bin/bash
for PKG_DIR in packages/*; do
  if [ -f "$PKG_DIR/package.json" ]; then
    PKG_NAME=$(jq -r '.name' "$PKG_DIR/package.json")
    IS_PRIVATE=$(jq -r '.private // false' "$PKG_DIR/package.json")

    if [ "$IS_PRIVATE" = "true" ]; then
      echo "⊘ $PKG_NAME (private)"
      continue
    fi

    if npm view "$PKG_NAME" version &>/dev/null; then
      PROV=$(npm view "$PKG_NAME" --json 2>&1 | jq -e '.provenance' 2>&1)
      if [ $? -eq 0 ]; then
        echo "✓ $PKG_NAME (OIDC configured)"
      else
        echo "⚠ $PKG_NAME (needs OIDC setup)"
        echo "  → https://www.npmjs.com/package/$PKG_NAME/settings"
      fi
    else
      echo "○ $PKG_NAME (not published yet)"
    fi
  fi
done
```

## Troubleshooting

### "No valid authentication token"

Both OIDC and NPM_TOKEN failed.

**Fix:**
1. Verify `NPM_PUBLISH_TOKEN` secret exists
2. Token has publish permissions
3. For existing packages, verify OIDC configured

### "Workflow name mismatch"

OIDC workflow filename doesn't match npm settings.

**Fix:** Ensure workflow filename in npm settings matches exactly (e.g., `ci.yml`)

### Provenance Not Showing

OIDC may be configured but provenance not generated.

**Fix:**
1. Ensure `id-token: write` permission in workflow
2. Use npm CLI 11.5+ (GitHub runners have this)
3. Use `--provenance` flag: `pnpm release --provenance`
