# Installation Guide

This guide covers how to install and use claude-devtools skills and commands with Claude Code and other AI coding agents.

## Quick Install (Claude Code)

```bash
# Clone the repository
git clone https://github.com/<username>/claude-devtools.git ~/.claude-devtools

# Run the installer (symlinks by default - recommended)
cd ~/.claude-devtools
chmod +x install.sh
./install.sh

# Or with copies (for independent installation)
./install.sh --copy
```

That's it! Commands now work in **all projects** automatically.

---

## Claude Code (Recommended)

### Installation

**Option 1: Automated Install (Recommended)**

```bash
# Clone repository
git clone https://github.com/<username>/claude-devtools.git ~/.claude-devtools
cd ~/.claude-devtools

# Make installer executable
chmod +x install.sh

# Install with symlinks (updates auto-propagate)
./install.sh

# Or install with copies (independent installation)
./install.sh --copy
```

**What it does:**
- Installs skills globally: `~/.claude/skills/user/devtools/`
- Installs commands globally: `~/.claude/commands/devtools/`
- Commands work in ALL projects automatically
- No per-project setup needed!

**Option 2: Manual Install**

```bash
# Clone repository
git clone https://github.com/<username>/claude-devtools.git ~/.claude-devtools

# Create directories
mkdir -p ~/.claude/skills/user
mkdir -p ~/.claude/commands

# Symlink (recommended - updates propagate)
ln -s ~/.claude-devtools/skills ~/.claude/skills/user/devtools
ln -s ~/.claude-devtools/commands/devtools ~/.claude/commands/devtools

# Or copy (independent - won't auto-update)
cp -r ~/.claude-devtools/skills ~/.claude/skills/user/devtools
cp -r ~/.claude-devtools/commands/devtools ~/.claude/commands/devtools
```

### Usage

Commands are available globally in ALL projects:

```bash
# Start Claude Code in any project
cd your-project
claude

# Use devtools commands
/devtools:develop "Add JWT authentication"
/devtools:setup-pypi
/devtools:validate

# See all commands
/help
# Look for commands marked "(user:devtools)"
```

**Why namespaced commands?**
- `/devtools:develop` - Clear ownership, no name conflicts
- `/devtools:test` - Doesn't clash with your own `/test` command
- `/devtools:setup-pypi` - Obvious it's from devtools

### Updating

**If you installed with symlinks (default):**
```bash
cd ~/.claude-devtools
git pull
# Done! Updates automatically available
```

**If you installed with copies:**
```bash
cd ~/.claude-devtools
git pull
./install.sh --copy
```

---

## Codex (OpenAI)

Codex automatically loads skills from the `AGENTS.md` file in the repository root.

### Installation

```bash
# Clone the repository to your workspace
git clone https://github.com/<username>/claude-devtools.git
cd claude-devtools
```

### Usage

Reference skills by name in your instructions:

```bash
# Quality gates
codex "Follow the feature-development skill to implement user authentication"

# Workflow generation
codex "Use the pypi-publishing skill to setup PyPI workflows for this project"

# Individual gates
codex "Use the testing-tdd skill to add tests for the auth module"
```

**Note:** Codex uses natural language, not `/command` syntax. It reads `AGENTS.md` automatically.

### Updating

```bash
cd /path/to/claude-devtools
git pull
# Skills automatically updated for next Codex session
```

---

## Gemini CLI (Google)

Gemini CLI uses an extension system to load skills.

### Installation

**From GitHub URL (Recommended):**
```bash
gemini extensions install https://github.com/<username>/claude-devtools.git --consent
```

**Local Installation:**
```bash
git clone https://github.com/<username>/claude-devtools.git
cd claude-devtools
gemini extensions install . --consent
```

### Verification

```bash
gemini extensions list
# Should show: claude-devtools
```

### Usage

Reference skills in your instructions:

```bash
# Quality gates
gemini "Use the devtools skills to implement authentication with full quality gates"

# Workflow generation
gemini "Setup PyPI publishing using the pypi-publishing skill"

# Individual operations
gemini "Follow the testing-setup skill to configure tests for this project"
```

### Updating

```bash
# Reinstall extension
gemini extensions install https://github.com/<username>/claude-devtools.git --consent --force
```

---

## Comparison Table

| Feature | Claude Code | Codex | Gemini CLI |
|---------|-------------|-------|------------|
| **Auto-discovery** | ✅ Global commands | ✅ AGENTS.md | ✅ Extensions |
| **Command syntax** | `/devtools:command` | Natural language | Natural language |
| **Install location** | `~/.claude/` | Project directory | Extension system |
| **Updates** | `git pull` | `git pull` | Re-install extension |
| **Per-project setup** | ❌ None needed | ❌ None needed | ❌ None needed |
| **Namespacing** | ✅ `/devtools:*` | ❌ N/A | ❌ N/A |

---

## Installation Methods Explained

### Symlink (Default - Recommended)

```bash
./install.sh
```

**Benefits:**
- ✅ Updates propagate automatically with `git pull`
- ✅ Single source of truth
- ✅ Easy to track changes in git
- ✅ Less disk space

**When to use:**
- You want updates automatically
- You're developing/testing the skills
- You want git history

### Copy (Optional)

```bash
./install.sh --copy
```

**Benefits:**
- ✅ Independent installation
- ✅ Won't change if you update repo
- ✅ Can customize without affecting others

**When to use:**
- You want a stable snapshot
- You plan to customize heavily
- You're in a restricted environment

---

## Verifying Installation

### Claude Code

```bash
# Check skills installed
ls ~/.claude/skills/user/devtools/
# Should show: testing-setup, testing-tdd, pypi-publishing, etc.

# Check commands installed
ls ~/.claude/commands/devtools/
# Should show: develop.md, setup-pypi.md, etc.

# Test in Claude Code
claude
> /help
# Look for commands marked "(user:devtools)"

> /devtools:develop "Add a hello world function"
```

### Codex

```bash
cd /path/to/claude-devtools
codex --ask-for-approval never "List available skills"
# Should mention devtools skills
```

### Gemini

```bash
gemini extensions list
# Should show: claude-devtools

gemini "What skills are available?"
# Should mention devtools skills
```

---

## Troubleshooting

### Commands Not Found (Claude Code)

**Check installation:**
```bash
ls ~/.claude/commands/devtools/
```

**If empty, reinstall:**
```bash
cd ~/.claude-devtools
./install.sh
```

**Restart Claude Code:**
Close and reopen Claude Code in any project.

### Skills Not Working

**Check skills directory:**
```bash
ls ~/.claude/skills/user/devtools/
```

**If empty, reinstall:**
```bash
cd ~/.claude-devtools
./install.sh
```

### Symlinks Broken

**Check if symlinks exist:**
```bash
ls -la ~/.claude/skills/user/devtools
ls -la ~/.claude/commands/devtools
```

**Should show something like:**
```
devtools -> /Users/you/.claude-devtools/skills
```

**If broken, recreate:**
```bash
cd ~/.claude-devtools
rm -rf ~/.claude/skills/user/devtools
rm -rf ~/.claude/commands/devtools
./install.sh
```

### Updates Not Propagating

**If you used symlinks:**
```bash
cd ~/.claude-devtools
git pull
# Updates immediately available
```

**If you used copies:**
```bash
cd ~/.claude-devtools
git pull
./install.sh --copy
# Must reinstall to get updates
```

---

## Uninstallation

### Claude Code

```bash
# Remove skills
rm -rf ~/.claude/skills/user/devtools

# Remove commands
rm -rf ~/.claude/commands/devtools

# Remove repository (optional)
rm -rf ~/.claude-devtools
```

### Codex

```bash
# Just remove the repository
rm -rf /path/to/claude-devtools
```

### Gemini CLI

```bash
gemini extensions uninstall claude-devtools
rm -rf /path/to/claude-devtools
```

---

## Support

- **Issues:** https://github.com/<username>/claude-devtools/issues
- **Discussions:** https://github.com/<username>/claude-devtools/discussions
- **Documentation:** See skill-specific SKILL.md files

---

## Next Steps

1. ✅ Install using method for your AI agent
2. ✅ Verify installation
3. ✅ Test with: `/devtools:develop "Add a simple function"`
4. ✅ Use in your actual projects
5. ✅ Customize skills as needed for your workflow
