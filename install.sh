#!/bin/bash
# Install claude-devtools v2 with symlinks (default) or copying (optional)
#
# This script is idempotent — every run cleans up previous devtools installations
# and reinstalls fresh. Just run it again whenever you add/remove/update skills.
#
# Skills are symlinked FLAT into ~/.claude/skills/<skill-name>/ so Claude Code
# discovers them at the expected depth (one level under ~/.claude/skills/).
#
# For full plugin features (hooks, marketplace), use the plugin system instead:
#   /plugin marketplace add ~/claude-devtools
#   /plugin install devtools@devtools-dev

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_METHOD="symlink"  # default

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --copy)
      INSTALL_METHOD="copy"
      shift
      ;;
    --help)
      cat << EOF
Usage: ./install.sh [OPTIONS]

Install claude-devtools v2 skills and commands globally for all projects.
Idempotent — safe to run repeatedly. Each run cleans up previous installations
and reinstalls fresh.

OPTIONS:
  --copy       Copy files instead of symlinking (default: symlink)
  --help       Show this help message

EXAMPLES:
  ./install.sh              # Install with symlinks (recommended)
  ./install.sh --copy       # Install with copies (independent)

WHAT IT DOES:
  - Cleans up any previous devtools installation (flat or legacy)
  - Installs each skill FLAT into ~/.claude/skills/<skill-name>/
    (Claude Code expects skills one level deep under ~/.claude/skills/)
  - Installs commands to ~/.claude/commands/devtools/

  Commands appear as:
    /devtools:quality-check
    /devtools:develop

SYMLINK vs COPY:
  Symlink (default):
    ✓ Updates propagate automatically when you git pull
    ✓ Single source of truth
    ✓ Easy to track changes
    ✓ Edits are picked up by Claude Code without reinstalling

  Copy (--copy flag):
    ✓ Independent installation
    ✓ Won't change if you update the repo
    ✓ Useful for customization

After installation, commands work in ALL projects automatically!
EOF
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "=================================="
echo "Claude DevTools v2 Installation"
echo "=================================="
echo ""

# Check if directories exist
if [ ! -d "$SCRIPT_DIR/skills" ]; then
    echo -e "${RED}✗ Error: skills/ directory not found${NC}"
    echo "  Make sure you're running this from the claude-devtools directory"
    exit 1
fi

if [ ! -d "$SCRIPT_DIR/commands" ]; then
    echo -e "${RED}✗ Error: commands/ directory not found${NC}"
    echo "  Make sure you're running this from the claude-devtools directory"
    exit 1
fi

# ── Cleanup previous installation ─────────────────────────────
echo -e "${BLUE}Cleaning up previous installation...${NC}"

CLEANED=false

# Remove flat symlinks/copies pointing into our repo
if [ -d ~/.claude/skills ]; then
    for entry in ~/.claude/skills/*/; do
        [ -d "$entry" ] || continue
        entry_path="${entry%/}"
        entry_name=$(basename "$entry_path")
        # Only touch entries with our devtools- prefix or symlinks pointing into our repo
        if [ -L "$entry_path" ]; then
            link_target=$(readlink "$entry_path")
            if [[ "$link_target" == "$SCRIPT_DIR/skills/"* ]]; then
                rm "$entry_path"
                CLEANED=true
            fi
        fi
    done
fi

# Remove legacy nested structure
if [ -L ~/.claude/skills/user/devtools ] || [ -d ~/.claude/skills/user/devtools ]; then
    rm -rf ~/.claude/skills/user/devtools
    rmdir ~/.claude/skills/user 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Removed legacy installation from ~/.claude/skills/user/devtools/"
    CLEANED=true
fi

# Remove existing commands
if [ -L ~/.claude/commands/devtools ] || [ -d ~/.claude/commands/devtools ]; then
    rm -rf ~/.claude/commands/devtools
    CLEANED=true
fi

if [ "$CLEANED" = true ]; then
    echo -e "${GREEN}✓${NC} Previous installation cleaned up"
else
    echo -e "  No previous installation found"
fi

echo ""

# ── Collect skills ─────────────────────────────────────────────
SKILL_DIRS=()
while IFS= read -r -d '' skill_md; do
    SKILL_DIRS+=("$(dirname "$skill_md")")
done < <(find "$SCRIPT_DIR/skills" -name "SKILL.md" -print0)

# Show what will be installed
echo -e "${BLUE}Skills to install (${#SKILL_DIRS[@]} skills, flat into ~/.claude/skills/):${NC}"
for skill_dir in "${SKILL_DIRS[@]}"; do
    skill_name=$(basename "$skill_dir")
    echo "  • $skill_name"
done

echo ""
echo -e "${BLUE}Commands to install:${NC}"
for cmd_file in "$SCRIPT_DIR/commands"/*.md; do
    if [ -f "$cmd_file" ]; then
        cmd_name=$(basename "$cmd_file" .md)
        echo "  • /devtools:$cmd_name"
    fi
done
echo ""

# ── Install ────────────────────────────────────────────────────
mkdir -p ~/.claude/skills
mkdir -p ~/.claude/commands

INSTALLED_SKILLS=()

if [[ "$INSTALL_METHOD" == "symlink" ]]; then
    echo -e "${GREEN}Installing skills with symlinks (flat)...${NC}"
    echo ""

    for skill_dir in "${SKILL_DIRS[@]}"; do
        skill_name="devtools-$(basename "$skill_dir")"
        target=~/.claude/skills/"$skill_name"

        # Check for name collision with non-devtools content
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo -e "${YELLOW}⚠  COLLISION: Skipping '$skill_name' — a non-symlink directory already exists at $target${NC}"
            echo -e "   ${YELLOW}This is NOT a devtools-managed skill. Remove it manually if you want devtools to manage it.${NC}"
            continue
        fi

        # Check for symlink owned by something else
        if [ -L "$target" ]; then
            link_target=$(readlink "$target")
            if [[ "$link_target" != "$SCRIPT_DIR/skills/"* ]]; then
                echo -e "${YELLOW}⚠  COLLISION: Skipping '$skill_name' — symlink exists pointing to $link_target (not managed by devtools)${NC}"
                continue
            fi
            rm "$target"
        fi

        ln -s "$skill_dir" "$target"
        INSTALLED_SKILLS+=("$skill_name")
        echo -e "${GREEN}✓${NC} $skill_name → $skill_dir"
    done

    echo ""

    # Symlink commands
    ln -s "$SCRIPT_DIR/commands" ~/.claude/commands/devtools
    echo -e "${GREEN}✓${NC} Commands symlinked to ~/.claude/commands/devtools/"

    echo ""
    echo -e "${GREEN}Installation complete (symlinked, flat)${NC}"
    echo -e "${YELLOW}Updates propagate automatically — just edit files and restart Claude Code${NC}"

else
    echo -e "${GREEN}Installing skills with copies (flat)...${NC}"
    echo ""

    for skill_dir in "${SKILL_DIRS[@]}"; do
        skill_name="devtools-$(basename "$skill_dir")"
        target=~/.claude/skills/"$skill_name"

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo -e "${YELLOW}⚠  COLLISION: Skipping '$skill_name' — a directory already exists at $target${NC}"
            echo -e "   ${YELLOW}Remove it manually if you want devtools to manage it.${NC}"
            continue
        fi

        # Remove stale symlink if present
        if [ -L "$target" ]; then
            rm "$target"
        fi

        cp -r "$skill_dir" "$target"
        INSTALLED_SKILLS+=("$skill_name")
        echo -e "${GREEN}✓${NC} $skill_name → copied"
    done

    echo ""

    # Copy commands
    cp -r "$SCRIPT_DIR/commands" ~/.claude/commands/devtools
    echo -e "${GREEN}✓${NC} Commands copied to ~/.claude/commands/devtools/"

    echo ""
    echo -e "${GREEN}Installation complete (copied, flat)${NC}"
    echo -e "${YELLOW}This is an independent copy — updates won't auto-propagate${NC}"
fi

# ── Verify ─────────────────────────────────────────────────────
echo ""
echo "Verifying installation..."

VERIFY_FAILED=0
VERIFY_COUNT=0

for skill_name in "${INSTALLED_SKILLS[@]}"; do
    if [ -f ~/.claude/skills/"$skill_name"/SKILL.md ]; then
        VERIFY_COUNT=$((VERIFY_COUNT + 1))
    else
        echo -e "${RED}✗${NC} Skill not found: $skill_name"
        VERIFY_FAILED=1
    fi
done

if [ $VERIFY_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓${NC} All $VERIFY_COUNT skills verified in ~/.claude/skills/"
else
    echo -e "${RED}Some skills failed verification${NC}"
fi

if [ -f ~/.claude/commands/devtools/quality-check.md ]; then
    echo -e "${GREEN}✓${NC} Commands installed"
else
    echo -e "${RED}✗${NC} Commands not found"
    VERIFY_FAILED=1
fi

if [ $VERIFY_FAILED -eq 1 ]; then
    echo ""
    echo -e "${RED}Installation verification failed${NC}"
    exit 1
fi

# ── Summary ────────────────────────────────────────────────────
echo ""
echo "=================================="
echo "Installed Skills (${#INSTALLED_SKILLS[@]})"
echo "=================================="
echo ""
for skill_name in "${INSTALLED_SKILLS[@]}"; do
    echo "  ~/.claude/skills/$skill_name/"
done

echo ""
echo "=================================="
echo "Next Steps"
echo "=================================="
echo ""
echo "1. Restart Claude Code or start a new session"
echo ""
echo "2. Test commands:"
echo "   cd your-project"
echo "   claude"
echo "   > /devtools:help"
echo ""
echo "3. Skills are now directly in ~/.claude/skills/ — Claude Code"
echo "   will discover them at the expected depth."
echo ""
echo -e "${GREEN}Installation successful!${NC}"
echo ""
