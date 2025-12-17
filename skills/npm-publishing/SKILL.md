# NPM Publishing Setup Skill

Set up automated npm publishing with GitHub Actions for TypeScript/JavaScript packages.

## Purpose

Configure automated npm publishing that publishes to npm on pushes to main and publishes RC (release candidate) versions on pull requests for testing.

## What Gets Created

This skill generates 1 file:

1. **`.github/workflows/publish-{package-name}.yml`** - Complete publish workflow

## Prerequisites

- Node.js/TypeScript project with `package.json`
- GitHub repository
- npm account (for NPM_TOKEN)

## Process

### 1. Gather Project Information

**From existing files:**
- Read `package.json` for package name, version
- Detect if monorepo by checking for `workspaces` in root package.json
- Check for `yarn.lock` or `package-lock.json`

**Ask user:**
- **Package directory**: Path to package relative to repo root
  - Monorepo example: `packages/my-lib`
  - Single package: `.` (root)
- **NPM package name**: From package.json `name` field
  - Should include scope if applicable: `@scope/package-name`
- **Git tag prefix**: Prefix for version tags
  - Monorepo example: `my-lib-v` (creates tags like `my-lib-v1.2.3`)
  - Single package: `v` (creates tags like `v1.2.3`)

**Configuration options:**
- **Node version**: Default `20` (or detect from `.nvmrc`, `package.json engines`)
- **NPM registry URL**: Default `https://registry.npmjs.org`
- **Build command**: Default `npm install && npm run build`
  - Adjust if using yarn: `yarn install && yarn build`
  - Adjust if no build step: `npm install`

### 2. Create Workflow File

Create `.github/workflows/` directory:
```bash
mkdir -p .github/workflows
```

**Read template**: `./templates/workflow.yml`

**Substitute variables:**
- `{{NPM_PACKAGE_NAME}}` → Package name from package.json
- `{{PACKAGE_DIR}}` → Path to package (e.g., `packages/my-lib` or `.`)
- `{{GIT_TAG_PREFIX}}` → Tag prefix (e.g., `my-lib-v` or `v`)
- `{{NODE_VERSION}}` → Node.js version (e.g., `20`)
- `{{NPM_REGISTRY_URL}}` → Registry URL (default: `https://registry.npmjs.org`)
- `{{BUILD_COMMAND}}` → Build command (e.g., `npm install && npm run build`)

**Generate output filename:**
- Slug the package name: `@scope/my-package` → `scope-my-package`
- Format: `publish-{slugged-name}.yml`
- Example: `publish-scope-my-package.yml`

**Write to**: `.github/workflows/publish-{slugged-name}.yml`

### 3. User Instructions

After generating the workflow, provide instructions:

```
✓ NPM publishing workflow created!

File generated:
- .github/workflows/publish-{{SLUGGED_NAME}}.yml

Next steps:

1. Create NPM Access Token:
   - Go to: https://www.npmjs.com/settings/YOUR_USERNAME/tokens
   - Click "Generate New Token"
   - Select "Automation" type
   - Copy the token

2. Add NPM_TOKEN to GitHub Secrets:
   - Go to: https://github.com/{{OWNER}}/{{REPO}}/settings/secrets/actions
   - Click "New repository secret"
   - Name: NPM_TOKEN
   - Value: [paste your npm token]
   - Click "Add secret"

3. Ensure package.json is configured:
   - Check "name" field matches: {{NPM_PACKAGE_NAME}}
   - Check "version" is set (e.g., "0.1.0")
   - If scoped package (@scope/name), ensure you have publish access
   - Add "files" field to specify what to publish:
     {
       "files": ["dist", "README.md", "package.json"]
     }

4. Commit and push:
   git add .github/workflows/
   git commit -m "Add npm publishing workflow"
   git push

5. How publishing works:

   **On push to main:**
   - Runs build command
   - Bumps patch version automatically (0.1.0 → 0.1.1)
   - Publishes to npm
   - Creates git tag: {{GIT_TAG_PREFIX}}0.1.1
   - Creates GitHub Release

   **On pull request:**
   - Runs build command
   - Creates RC version: 0.1.1-rc.abc1234
   - Publishes to npm with "rc" tag
   - Install with: npm install {{NPM_PACKAGE_NAME}}@rc

6. Manual version bumps (if needed):
   cd {{PACKAGE_DIR}}
   npm version minor  # 0.1.0 → 0.2.0
   npm version major  # 0.2.0 → 1.0.0
   git push && git push --tags
```

## Validation

Before completing, verify:

```bash
# Check workflow file exists
ls .github/workflows/publish-*.yml

# Check package.json exists in package directory
ls {{PACKAGE_DIR}}/package.json

# Validate package.json has required fields
node -e "const pkg = require('./{{PACKAGE_DIR}}/package.json'); console.log('Name:', pkg.name, 'Version:', pkg.version)"
```

## How It Works

### Automatic Publishing (main branch)

**Trigger**: Push to `main` branch with changes in package directory

**Process**:
1. Checkout code
2. Setup Node.js with npm registry
3. Cache dependencies (yarn cache)
4. Install dependencies and build
5. Bump patch version automatically
6. Publish to npm
7. Create and push git tag
8. Create GitHub Release

### RC Publishing (pull requests)

**Trigger**: Pull request with changes in package directory

**Process**:
1. Checkout code
2. Setup Node.js
3. Cache and install dependencies
4. Build package
5. Create RC version (e.g., `1.0.0-rc.abc1234`)
6. Publish to npm with `rc` tag

**Testing RC versions:**
```bash
# Install specific RC version
npm install @scope/package@rc

# Or specific version
npm install @scope/package@1.0.0-rc.abc1234
```

### Monorepo Support

For monorepos, the workflow only runs when files in the specific package directory change:

```yaml
on:
  push:
    paths:
      - 'packages/my-lib/**'
```

This prevents unnecessary workflow runs when other packages change.

## Troubleshooting

**NPM publish fails with 403:**
- Check NPM_TOKEN secret is set correctly
- Verify npm token has "Automation" type (not "Read Only")
- If scoped package (@scope/name), ensure you have access to the scope

**Git tag already exists:**
- Workflow creates tag with current version
- If tag exists, git push --tags will fail
- Solution: Delete remote tag or bump version manually first

**Build fails:**
- Check BUILD_COMMAND is correct for your project
- Verify all dependencies are in package.json
- Test build locally: `cd {{PACKAGE_DIR}} && npm install && npm run build`

**RC versions not publishing:**
- PR must have changes in package directory
- NPM_TOKEN must be set
- Check workflow runs in "Actions" tab

**Wrong package gets published:**
- Verify `working-directory` in workflow matches package location
- Check `package.json` in that directory has correct name

## Configuration Options

All substitution variables:

```
{{NPM_PACKAGE_NAME}}  - Full npm package name (e.g., @scope/package)
{{PACKAGE_DIR}}       - Path to package (e.g., packages/my-lib or .)
{{GIT_TAG_PREFIX}}    - Tag prefix (e.g., my-lib-v or v)
{{NODE_VERSION}}      - Node.js version (default: 20)
{{NPM_REGISTRY_URL}}  - npm registry (default: https://registry.npmjs.org)
{{BUILD_COMMAND}}     - Build command (default: npm install && npm run build)
{{SLUGGED_NAME}}      - Package name slugified for filename
{{OWNER}}             - GitHub username or org
{{REPO}}              - Repository name
```

## Best Practices

**Monorepo:**
- Use unique tag prefix per package: `api-v`, `sdk-v`, `cli-v`
- Prevents tag conflicts between packages
- Makes it clear which package a tag belongs to

**Version Management:**
- Let workflow handle patch bumps automatically
- Use manual `npm version` for minor/major bumps
- Keep versions in sync between package.json and git tags

**Package Configuration:**
- Use `files` field in package.json to control what's published
- Include only necessary files: `["dist", "README.md", "LICENSE"]`
- Exclude source files, tests, configs: use `.npmignore` if needed

**Testing:**
- Always test RC versions from PRs before merging
- RC versions won't affect your main package
- Users must explicitly install RC versions

## Output Confirmation

```
✓ NPM publishing configured
✓ Workflow file created
✓ package.json validated
✓ Instructions provided to user
```

## Next Steps

After setup:
- User creates NPM_TOKEN and adds to GitHub Secrets
- User commits and pushes workflow file
- On next push to main, package auto-publishes
- On PRs, RC versions available for testing
