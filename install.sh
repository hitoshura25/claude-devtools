#!/bin/bash
# Install claude-devtools with symlinks (default) or copying (optional)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_METHOD="symlink"  # default

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

Install claude-devtools skills and commands globally for all projects.

OPTIONS:
  --copy    Copy files instead of symlinking (default: symlink)
  --help    Show this help message

EXAMPLES:
  ./install.sh           # Install with symlinks (recommended)
  ./install.sh --copy    # Install with copies (independent)

WHAT IT DOES:
  - Installs skills to ~/.claude/skills/user/devtools/ (global, all projects)
  - Installs commands to ~/.claude/commands/devtools/ (global, all projects)
  - Commands appear as /devtools:develop, /devtools:setup-pypi, etc.

SYMLINK vs COPY:
  Symlink (default):
    ✓ Updates propagate automatically when you git pull
    ✓ Single source of truth
    ✓ Easy to track changes
    
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
echo "Claude DevTools Installation"
echo "=================================="
echo ""

# Check if directories exist
if [ ! -d "$SCRIPT_DIR/skills" ]; then
    echo -e "${RED}✗ Error: skills/ directory not found${NC}"
    exit 1
fi

if [ ! -d "$SCRIPT_DIR/commands" ]; then
    echo -e "${RED}✗ Error: commands/ directory not found${NC}"
    exit 1
fi

# Create directories if they don't exist
mkdir -p ~/.claude/skills/user
mkdir -p ~/.claude/commands

# Remove existing installations
if [ -L ~/.claude/skills/user/devtools ] || [ -d ~/.claude/skills/user/devtools ]; then
    echo -e "${YELLOW}Existing skills installation found at ~/.claude/skills/user/devtools/${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing existing skills installation...${NC}"
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
        echo -e "${YELLOW}Removing existing commands installation...${NC}"
        rm -rf ~/.claude/commands/devtools
    else
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
fi

# Install based on method
if [[ "$INSTALL_METHOD" == "symlink" ]]; then
    echo -e "${GREEN}Installing with symlinks...${NC}"
    echo ""
    
    # Symlink skills
    ln -s "$SCRIPT_DIR/skills" ~/.claude/skills/user/devtools
    echo -e "${GREEN}✓${NC} Skills symlinked to ~/.claude/skills/user/devtools/"
    
    # Symlink commands  
    ln -s "$SCRIPT_DIR/commands/devtools" ~/.claude/commands/devtools
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
    cp -r "$SCRIPT_DIR/commands/devtools" ~/.claude/commands/devtools
    echo -e "${GREEN}✓${NC} Commands copied to ~/.claude/commands/devtools/"
    
    echo ""
    echo -e "${GREEN}Installation complete (copied)${NC}"
    echo -e "${YELLOW}This is an independent copy - updates won't auto-propagate${NC}"
fi

# Verify installation
echo ""
echo "Verifying installation..."
if [ -d ~/.claude/skills/user/devtools/testing-setup ]; then
    echo -e "${GREEN}✓${NC} Skills installed correctly"
else
    echo -e "${RED}✗${NC} Skills installation failed"
    exit 1
fi

if [ -f ~/.claude/commands/devtools/develop.md ]; then
    echo -e "${GREEN}✓${NC} Commands installed correctly"
else
    echo -e "${RED}✗${NC} Commands installation failed"
    exit 1
fi

# Show available commands
echo ""
echo "=================================="
echo "Available Commands"
echo "=================================="
echo ""
echo "Quality Gates:"
echo "  /devtools:develop   - Full feature development with quality gates"
echo "  /devtools:validate  - Run all quality checks"
echo "  /devtools:test      - Setup and run tests"
echo "  /devtools:lint      - Setup and run linting"
echo "  /devtools:security  - Setup and run security scans"
echo ""
echo "Workflow Generation:"
echo "  /devtools:setup-pypi - Setup PyPI publishing workflow"
echo "  /devtools:setup-npm  - Setup npm publishing workflow"
echo ""
echo "=================================="
echo "Next Steps"
echo "=================================="
echo ""
echo "1. Restart Claude Code or start a new session"
echo "2. Test a command:"
echo "   cd your-project"
echo "   claude"
echo "   > /devtools:develop \"Add a fibonacci function\""
echo ""
echo "3. See all commands: /help"
echo "   (Look for 'devtools' commands)"
echo ""
echo -e "${GREEN}Installation successful!${NC}"
echo ""
