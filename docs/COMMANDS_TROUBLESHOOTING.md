# Commands Not Found - Quick Fix

## Symptom

You've installed skills globally but Claude Code doesn't recognize commands like `/develop`, `/setup-pypi`, etc.

## Cause

**Skills are global, but commands are per-project.**

You need both:
1. ✅ Skills installed globally (user-level) - you did this
2. ❌ Commands installed in current project - missing

## Solution

In **every project** where you want to use commands:

```bash
# Navigate to your project
cd your-project

# Copy commands file
mkdir -p .claude
cp /Users/vinayakmenon/claude-devtools/commands/commands.json .claude/

# Verify
ls .claude/commands.json
```

Then restart Claude Code or start new session.

## Understanding the Architecture

```
~/.claude/skills/user/devtools/     ← Global skills (install once)
    ├── testing-setup/
    ├── testing-tdd/
    ├── pypi-publishing/
    └── ...

your-project/.claude/                ← Project commands (per project)
    └── commands.json                ← References global skills
```

**Why separate?**
- **Skills** contain the actual instructions and templates
- **Commands** are shortcuts that reference skills
- Projects can customize commands while sharing skills

## Quick Setup Script

Create `~/.claude-devtools/install-commands.sh`:

```bash
#!/bin/bash
# Install commands in current project

if [ ! -f ".claude/commands.json" ]; then
    mkdir -p .claude
    cp ~/.claude-devtools/commands/commands.json .claude/
    echo "✓ Commands installed in $(pwd)"
else
    echo "✓ Commands already installed"
fi
```

Make executable:
```bash
chmod +x ~/.claude-devtools/install-commands.sh
```

Use in any project:
```bash
cd your-project
~/.claude-devtools/install-commands.sh
```

## Verification Checklist

Before using commands, verify:

```bash
# 1. Skills are installed globally
ls ~/.claude/skills/user/devtools/
# Should show: testing-setup, testing-tdd, etc.

# 2. Commands are in current project
ls .claude/commands.json
# Should exist

# 3. Commands reference correct paths
cat .claude/commands.json
# Should show paths to ~/.claude-devtools/skills/
```

## Testing After Installation

```bash
# In your project directory with commands.json
# Start Claude Code and try:
/develop "Add a simple function"

# Should work now!
```

## Alternative: Use Skills Without Commands

If you don't want to copy commands.json to every project, you can still use skills by referencing them directly:

```bash
# Instead of:
/develop "Add authentication"

# Use:
"Follow the feature-development skill at ~/.claude/skills/user/devtools/feature-development/SKILL.md to add authentication"
```

This works but is more verbose. Commands are shortcuts for convenience.

## Common Issues

### Issue: Commands work in one project but not another

**Solution:** You need commands.json in **each** project.

```bash
cd problematic-project
cp ~/.claude-devtools/commands/commands.json .claude/
```

### Issue: Path not found errors

**Solution:** Check paths in commands.json match your installation:

```bash
# View commands
cat .claude/commands.json

# Paths should match:
ls ~/.claude-devtools/skills/feature-development/SKILL.md
```

If paths don't match, edit commands.json or reinstall skills.

### Issue: Commands don't update

**Solution:** If you update skills, you may need to update commands:

```bash
cd ~/.claude-devtools
git pull

# Then update commands in projects
cd your-project
cp ~/.claude-devtools/commands/commands.json .claude/
```

## Best Practices

1. **Install commands in project root** - Where you run Claude Code
2. **Commit .claude/ to git** - So team members get commands too
3. **Update periodically** - When skills are updated
4. **Customize per project** - Different projects can have different commands

## Template for New Projects

Create this template to speed up new project setup:

**~/.claude-devtools/new-project-template/.claude/commands.json**

Copy to new projects:
```bash
mkdir new-project
cd new-project
git init
cp -r ~/.claude-devtools/new-project-template/.claude .
```

Or add to your project scaffolding tools.

## Summary

**Two-step installation:**
1. ✅ Skills once globally: `ln -s ~/.claude-devtools/skills ~/.claude/skills/user/devtools`
2. ✅ Commands per project: `cp ~/.claude-devtools/commands/commands.json .claude/`

**Remember:** Skills are shared, commands are per-project!

---

**Still having issues?** Check:
- Restart Claude Code after copying commands
- Verify paths in commands.json are correct
- Ensure .claude/commands.json exists in current directory
- Try the verbose skill reference instead of commands
