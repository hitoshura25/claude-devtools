# Linting Setup Skill

Ensure the project has linting tools configured for code quality and consistency.

## Purpose

Before running lint checks, verify that appropriate linting tools are installed and configured. If not, set up linters for the project's language with sensible defaults.

## Detection Logic

Check for linter indicators based on project type:

### TypeScript/JavaScript Projects
Look for:
- `.eslintrc.js`, `.eslintrc.json`, or `eslint.config.js` config files
- `eslint` in `package.json` devDependencies
- `"lint"` script in `package.json`
- `.prettierrc` or `prettier.config.js` for formatting

### Python Projects
Look for:
- `.ruff.toml`, `ruff.toml`, or `pyproject.toml` with `[tool.ruff]`
- `ruff` in requirements or pyproject.toml dependencies
- Alternative: `.pylintrc` or `pyproject.toml` with `[tool.pylint]`
- `.flake8` configuration file

### Kotlin/Android Projects
Look for:
- `.editorconfig` file
- `ktlint` or `detekt` in `build.gradle.kts` dependencies
- Gradle tasks for linting

## Setup Actions

If no linter is detected, install and configure recommended tools:

### For TypeScript/JavaScript

**ESLint (Primary Linter):**
```bash
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npx eslint --init
```

**Or for simpler setup:**
```bash
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

Create `.eslintrc.js`:
```javascript
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
  },
  rules: {
    // Custom rules can be added here
  },
};
```

**Prettier (Code Formatter - Optional but Recommended):**
```bash
npm install --save-dev prettier eslint-config-prettier
```

Create `.prettierrc`:
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
```

**Add Scripts to package.json:**
```json
{
  "scripts": {
    "lint": "eslint . --ext .ts,.tsx,.js,.jsx",
    "lint:fix": "eslint . --ext .ts,.tsx,.js,.jsx --fix",
    "format": "prettier --write \"src/**/*.{ts,tsx,js,jsx,json,css,md}\"",
    "format:check": "prettier --check \"src/**/*.{ts,tsx,js,jsx,json,css,md}\""
  }
}
```

### For Python

**Ruff (Modern, Fast - Recommended):**
```bash
pip install ruff
```

Create `ruff.toml` or add to `pyproject.toml`:
```toml
[tool.ruff]
# Same as Black.
line-length = 88
indent-width = 4

# Assume Python 3.11+
target-version = "py311"

[tool.ruff.lint]
# Enable pycodestyle (`E`) and Pyflakes (`F`) codes by default.
select = ["E", "F", "W", "I", "N", "UP", "B", "A", "C4", "T20"]
ignore = []

# Allow fix for all enabled rules (when `--fix`) is provided.
fixable = ["ALL"]
unfixable = []

# Allow unused variables when underscore-prefixed.
dummy-variable-rgx = "^(_+|(_+[a-zA-Z0-9_]*[a-zA-Z0-9]+?))$"

[tool.ruff.format]
# Like Black, use double quotes for strings.
quote-style = "double"

# Like Black, indent with spaces, rather than tabs.
indent-style = "space"

# Like Black, respect magic trailing commas.
skip-magic-trailing-comma = false

# Like Black, automatically detect the appropriate line ending.
line-ending = "auto"
```

**Alternative: Pylint (Traditional):**
```bash
pip install pylint
```

Create `.pylintrc`:
```ini
[MASTER]
ignore=tests,migrations
max-line-length=100

[MESSAGES CONTROL]
disable=C0111,R0903,C0103

[DESIGN]
max-args=7
max-locals=15
```

### For Kotlin/Android

**ktlint (Kotlin Linter):**

Add to `build.gradle.kts`:
```kotlin
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "11.6.1"
}

ktlint {
    version.set("1.0.1")
    debug.set(false)
    verbose.set(true)
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
}
```

**Detekt (Static Analysis):**

Add to `build.gradle.kts`:
```kotlin
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.3"
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("$projectDir/config/detekt/detekt.yml"))
}

dependencies {
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.3")
}
```

Create `config/detekt/detekt.yml`:
```yaml
build:
  maxIssues: 0

complexity:
  active: true
  LongMethod:
    threshold: 60

style:
  active: true
  MagicNumber:
    ignoreNumbers: ['-1', '0', '1', '2']
```

**.editorconfig (Universal):**
```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{kt,kts}]
indent_style = space
indent_size = 4
max_line_length = 120

[*.{js,ts,json,yml,yaml}]
indent_style = space
indent_size = 2
```

## Verification

After setup, verify linter works:

**TypeScript/JavaScript:**
```bash
npm run lint
# Should run without errors (may show warnings for existing code)
```

**Python:**
```bash
ruff check .
# Or
pylint your_package/
```

**Kotlin:**
```bash
./gradlew ktlintCheck
./gradlew detekt
```

## Handle Legacy Code

If linter finds many existing issues in legacy code:

**Option 1: Fix All (Preferred for small projects):**
```bash
# Auto-fix what's possible
npm run lint:fix  # TypeScript
ruff check --fix .  # Python
./gradlew ktlintFormat  # Kotlin
```

**Option 2: Baseline (For large legacy projects):**

Create baseline to ignore existing issues, only check new code:

**Python with Ruff:**
```bash
# Generate baseline
ruff check --output-format=json > .ruff-baseline.json
```

**Kotlin with Detekt:**
```bash
./gradlew detektBaseline
```

Document in README:
```markdown
## Linting

We use [tool] for code quality. Legacy code has a baseline - 
new code must pass all checks without exceptions.
```

## Output Confirmation

Once linting is configured and verified:

```
✓ Linter configured: [eslint/ruff/ktlint]
✓ Lint command works: [npm run lint/ruff check/gradle ktlintCheck]
✓ Configuration file created: [.eslintrc.js/ruff.toml/.editorconfig]
```

## Best Practices

### Start Strict, Relax as Needed

Begin with recommended rules, disable only when necessary:
```javascript
// .eslintrc.js
rules: {
  '@typescript-eslint/no-explicit-any': 'warn',  // Soften strict rule
  'no-console': 'off',  // Allow console logs in dev
}
```

### Auto-Fix on Save (IDE Setup)

Encourage team to configure IDE:

**VSCode settings.json:**
```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff"
  }
}
```

### Pre-Commit Hooks (Advanced)

Consider adding lint checks to pre-commit hooks:
```bash
npm install --save-dev husky lint-staged
npx husky install
```

`.husky/pre-commit`:
```bash
#!/bin/sh
npm run lint
```

## Common Issues

**Node version mismatch:**
- Some ESLint plugins require specific Node versions
- Document required version in README

**Import resolution:**
- TypeScript paths may need eslint-import-resolver-typescript
- Add to .eslintrc.js settings

**Formatter conflicts:**
- ESLint and Prettier can conflict on formatting rules
- Use eslint-config-prettier to disable ESLint formatting rules

## Next Steps

After linting is set up:
- Run lint checks on code changes (see `linting-check` skill)
- Integrate into CI/CD pipelines
- Configure IDE auto-fix for better developer experience
