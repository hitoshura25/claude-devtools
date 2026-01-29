#!/bin/bash
# Install claude-devtools v2 with symlinks (default) or copying (optional)
#
# This script installs skills and commands globally for all projects.
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
    --uninstall)
      echo "=================================="
      echo "Claude DevTools Uninstallation"
      echo "=================================="
      echo ""
      
      if [ -L ~/.claude/skills/user/devtools ] || [ -d ~/.claude/skills/user/devtools ]; then
        rm -rf ~/.claude/skills/user/devtools
        echo -e "${GREEN}✓${NC} Removed skills from ~/.claude/skills/user/devtools/"
      else
        echo -e "${YELLOW}⊘${NC} No skills installation found"
      fi
      
      if [ -L ~/.claude/commands/devtools ] || [ -d ~/.claude/commands/devtools ]; then
        rm -rf ~/.claude/commands/devtools
        echo -e "${GREEN}✓${NC} Removed commands from ~/.claude/commands/devtools/"
      else
        echo -e "${YELLOW}⊘${NC} No commands installation found"
      fi
      
      echo ""
      echo -e "${GREEN}Uninstallation complete${NC}"
      exit 0
      ;;
    --help)
      cat << EOF
Usage: ./install.sh [OPTIONS]

Install claude-devtools v2 skills and commands globally for all projects.

OPTIONS:
  --copy       Copy files instead of symlinking (default: symlink)
  --uninstall  Remove existing installation
  --help       Show this help message

EXAMPLES:
  ./install.sh              # Install with symlinks (recommended)
  ./install.sh --copy       # Install with copies (independent)
  ./install.sh --uninstall  # Remove installation

WHAT IT DOES:
  - Installs skills to ~/.claude/skills/user/devtools/
  - Installs commands to ~/.claude/commands/devtools/
  
  Commands appear as:
    /devtools:quality-check
    /devtools:develop

SYMLINK vs COPY:
  Symlink (default):
    ✓ Updates propagate automatically when you git pull
    ✓ Single source of truth
    ✓ Easy to track changes
    
  Copy (--copy flag):
    ✓ Independent installation
    ✓ Won't change if you update the repo
    ✓ Useful for customization

PLUGIN INSTALLATION (Alternative):
  For full plugin features including session hooks, use:
    /plugin marketplace add ~/claude-devtools
    /plugin install devtools@devtools-dev

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

# Show what will be installed
echo -e "${BLUE}Skills to install:${NC}"
for skill_dir in "$SCRIPT_DIR/skills"/*/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name=$(basename "$skill_dir")
        echo "  • $skill_name"
    fi
done
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name=$(basename "$skill_dir")
        echo "  • $skill_name"
    fi
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

# Create directories if they don't exist
mkdir -p ~/.claude/skills/user
mkdir -p ~/.claude/commands

# Remove existing installations
if [ -L ~/.claude/skills/user/devtools ] || [ -d ~/.claude/skills/user/devtools ]; then
    echo -e "${YELLOW}Existing skills installation found at ~/.claude/skills/user/devtools/${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing skills installation..."
        rm -rf ~/.claude/skills/user/devtools
    else
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
fi

if [ -L ~/.claude/commands/devtools ] || [ -d ~/.claude/commands/devtools ]; then
    echo -e "${YELLOW}Existing commands installation found at ~/.claude/commands/devtools/${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing commands installation..."
        rm -rf ~/.claude/commands/devtools
    else
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
fi

echo ""

# Install based on method
if [[ "$INSTALL_METHOD" == "symlink" ]]; then
    echo -e "${GREEN}Installing with symlinks...${NC}"
    echo ""
    
    # Symlink skills
    ln -s "$SCRIPT_DIR/skills" ~/.claude/skills/user/devtools
    echo -e "${GREEN}✓${NC} Skills symlinked to ~/.claude/skills/user/devtools/"
    
    # Symlink commands (the whole commands directory becomes devtools/)
    ln -s "$SCRIPT_DIR/commands" ~/.claude/commands/devtools
    echo -e "${GREEN}✓${NC} Commands symlinked to ~/.claude/commands/devtools/"
    
    echo ""
    echo -e "${GREEN}Installation complete (symlinked)${NC}"
    echo -e "${YELLOW}Updates will automatically propagate when you git pull${NC}"
    
else
    echo -e "${GREEN}Installing with copies...${NC}"
    echo ""
    
    # Copy skills
    cp -r "$SCRIPT_DIR/skills" ~/.claude/skills/user/devtools
    echo -e "${GREEN}✓${NC} Skills copied to ~/.claude/skills/user/devtools/"
    
    # Copy commands
    cp -r "$SCRIPT_DIR/commands" ~/.claude/commands/devtools
    echo -e "${GREEN}✓${NC} Commands copied to ~/.claude/commands/devtools/"
    
    echo ""
    echo -e "${GREEN}Installation complete (copied)${NC}"
    echo -e "${YELLOW}This is an independent copy - updates won't auto-propagate${NC}"
fi

# Verify installation
echo ""
echo "Verifying installation..."

VERIFY_FAILED=0

# Check for a quality-gates skill
if [ -d ~/.claude/skills/user/devtools/quality-gates/lint-typescript ]; then
    echo -e "${GREEN}✓${NC} Quality gate skills installed"
else
    echo -e "${RED}✗${NC} Quality gate skills not found"
    VERIFY_FAILED=1
fi

# Check for workflow skills
if [ -d ~/.claude/skills/user/devtools/workflows/npm-publish ]; then
    echo -e "${GREEN}✓${NC} Workflow skills installed"
else
    echo -e "${RED}✗${NC} Workflow skills not found"
    VERIFY_FAILED=1
fi

# Check for commands
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

# Show available commands and skills
echo ""
echo "=================================="
echo "Available Commands"
echo "=================================="
echo ""
echo -e "${BLUE}Commands:${NC}"
echo "  /devtools:help           - List all skills and usage examples"
echo "  /devtools:quality-check  - Run all quality gates (lint, security, AI review)"
echo "  /devtools:develop        - Full feature development with planning and TDD"
echo ""
echo -e "${BLUE}Quality Gate Skills:${NC}"
echo "  lint-typescript          - ESLint + Prettier for TypeScript/JavaScript"
echo "  lint-python              - Ruff for Python"
echo "  lint-kotlin              - ktlint for Kotlin/Android"
echo "  security-scanning        - Semgrep + OSV-Scanner"
echo "  ai-code-review           - Local AI review via Ollama"
echo ""
echo -e "${BLUE}Workflow Skills:${NC}"
echo "  npm-publish              - npm publishing with Changesets (monorepo support)"
echo "  pypi-publish             - PyPI publishing with Trusted Publishers"
echo "  android-release          - Play Store deployment with Fastlane"
echo "  version-management       - Semantic versioning with git tags"
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
echo "3. See all commands: /help"
echo "   (Look for 'devtools' commands)"
echo ""
echo -e "${GREEN}Installation successful!${NC}"
echo ""
