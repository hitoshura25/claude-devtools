#!/bin/bash
# SERA Implementation Skill - One-time Setup
# Installs MLX, downloads model, configures Goose provider
#
# Uses `uv` for Python version management to ensure Python 3.12
# (mlx-openai-server requires Python >=3.11, <3.13)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Model configuration
MODEL="hitoshura25/SERA-32B-mlx-4Bit"

# Paths
SERA_VENV="${HOME}/.sera-venv"
GOOSE_CONFIG_DIR="${HOME}/.config/goose"
GOOSE_PROVIDERS_DIR="${GOOSE_CONFIG_DIR}/custom_providers"

PROVIDER_NAME="sera_mlx"

# Required Python version (mlx-openai-server needs <3.13)
REQUIRED_PYTHON="3.12"

echo "=== SERA Implementation Skill Setup ==="
echo ""

# Check for Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    echo "❌ Error: SERA requires Apple Silicon (M1/M2/M3/M4)"
    exit 1
fi

# Step 1: Install uv if not present
echo "[1/5] Checking uv installation..."
if ! command -v uv &>/dev/null; then
    echo "⏳ Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Add to PATH for this session
    export PATH="${HOME}/.local/bin:${PATH}"
    
    if command -v uv &>/dev/null; then
        echo "✅ uv installed"
    else
        echo "❌ uv installation failed"
        echo "Please install manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
else
    echo "✅ uv already installed ($(uv --version))"
fi

# Step 2: Create Python 3.12 virtual environment
echo ""
echo "[2/5] Creating Python ${REQUIRED_PYTHON} virtual environment..."
if [[ -d "$SERA_VENV" ]]; then
    # Check if existing venv has correct Python version
    VENV_PYTHON_VERSION=$("${SERA_VENV}/bin/python" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ "$VENV_PYTHON_VERSION" == "$REQUIRED_PYTHON" ]]; then
        echo "✅ Virtual environment exists with Python ${VENV_PYTHON_VERSION}"
    else
        echo "⚠️  Existing venv has Python ${VENV_PYTHON_VERSION}, need ${REQUIRED_PYTHON}"
        echo "⏳ Recreating virtual environment..."
        rm -rf "$SERA_VENV"
        uv venv "$SERA_VENV" --python "$REQUIRED_PYTHON"
        echo "✅ Virtual environment created with Python ${REQUIRED_PYTHON}"
    fi
else
    echo "⏳ Creating virtual environment with Python ${REQUIRED_PYTHON}..."
    uv venv "$SERA_VENV" --python "$REQUIRED_PYTHON"
    echo "✅ Virtual environment created at ${SERA_VENV}"
fi

# Step 3: Install MLX packages
echo ""
echo "[3/5] Installing MLX packages..."

# mlx-openai-server has proper tool calling support
# Note: mlx_lm.server crashes on tool call messages (KeyError: 'content')
# Require >=1.5.0 for --tool-call-parser support
# --prerelease=allow: mlx-lm depends on transformers pre-release (5.0.0rcX)
uv pip install --python "${SERA_VENV}/bin/python" \
    --prerelease=allow \
    "mlx-lm>=0.25.0" \
    "mlx-openai-server>=1.5.0"

echo "✅ MLX packages installed"

# Verify mlx-openai-server version
MLX_SERVER_VERSION=$(uv pip show --python "${SERA_VENV}/bin/python" mlx-openai-server 2>/dev/null | grep Version | cut -d' ' -f2)
echo "   mlx-openai-server version: ${MLX_SERVER_VERSION}"

# Step 4: Download model (this takes a while - 18.4GB)
echo ""
echo "[4/5] Downloading SERA model (18.4GB - this may take a while)..."
if "${SERA_VENV}/bin/python" -c "from mlx_lm import load; load('$MODEL')" 2>/dev/null; then
    echo "✅ Model already downloaded and cached"
else
    echo "⏳ Downloading model..."
    "${SERA_VENV}/bin/python" -c "from mlx_lm import load; load('$MODEL')"
    echo "✅ Model downloaded"
fi

# Step 5: Install Goose and configure provider
echo ""
echo "[5/5] Checking Goose installation and configuring provider..."
if ! command -v goose &>/dev/null && ! [[ -f "${HOME}/.local/bin/goose" ]]; then
    echo "⏳ Installing Goose..."
    set +e
    curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash
    set -e

    if [[ -f "${HOME}/.local/bin/goose" ]]; then
        echo "✅ Goose binary installed"
        export PATH="${HOME}/.local/bin:${PATH}"
    elif command -v goose &>/dev/null; then
        echo "✅ Goose installed"
    else
        echo "❌ Goose installation failed"
        echo "Please install Goose manually: https://github.com/block/goose"
        exit 1
    fi
else
    echo "✅ Goose already installed"
fi

# Ensure goose is in PATH for subsequent steps
if [[ -f "${HOME}/.local/bin/goose" ]] && ! command -v goose &>/dev/null; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# Create provider directory and JSON
mkdir -p "$GOOSE_PROVIDERS_DIR"

cat > "${GOOSE_PROVIDERS_DIR}/${PROVIDER_NAME}.json" << EOF
{
  "name": "${PROVIDER_NAME}",
  "engine": "openai",
  "display_name": "SERA MLX Local",
  "description": "Local SERA-32B via MLX for implementation tasks",
  "api_key_env": "SERA_API_KEY",
  "base_url": "http://localhost:8080/v1",
  "models": [
    {
      "name": "${MODEL}",
      "context_limit": 32000
    }
  ],
  "supports_streaming": true
}
EOF
echo "✅ Provider created: ${GOOSE_PROVIDERS_DIR}/${PROVIDER_NAME}.json"

# Update main config with defaults
GOOSE_CONFIG_FILE="${GOOSE_CONFIG_DIR}/config.yaml"
mkdir -p "$(dirname "$GOOSE_CONFIG_FILE")"

if [[ -f "$GOOSE_CONFIG_FILE" ]]; then
    cp "$GOOSE_CONFIG_FILE" "${GOOSE_CONFIG_FILE}.bak"
    echo "   Backed up existing config to ${GOOSE_CONFIG_FILE}.bak"
fi

cat > "$GOOSE_CONFIG_FILE" << EOF
# Goose configuration for SERA
# Default provider and model
GOOSE_PROVIDER: ${PROVIDER_NAME}
GOOSE_MODEL: ${MODEL}

# Extensions enabled by default
extensions:
  developer:
    enabled: true
EOF
echo "✅ Default config updated: ${GOOSE_CONFIG_FILE}"

# Add env var to shell profile if not present
SHELL_PROFILE=""
if [[ -f ~/.zshrc ]]; then
    SHELL_PROFILE=~/.zshrc
elif [[ -f ~/.bashrc ]]; then
    SHELL_PROFILE=~/.bashrc
fi

if [[ -n "$SHELL_PROFILE" ]] && ! grep -q "SERA_API_KEY" "$SHELL_PROFILE" 2>/dev/null; then
    echo "" >> "$SHELL_PROFILE"
    echo "# SERA MLX configuration" >> "$SHELL_PROFILE"
    echo 'export SERA_API_KEY="local"' >> "$SHELL_PROFILE"
    echo "✅ Added SERA_API_KEY to ${SHELL_PROFILE}"
fi

# Export for current session
export SERA_API_KEY="local"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Virtual environment: ${SERA_VENV}"
echo "Python version:      ${REQUIRED_PYTHON}"
echo "Provider:            ${PROVIDER_NAME}"
echo ""
echo "To start the SERA server:"
echo "  ${SKILL_DIR}/scripts/sera-server.sh start"
echo ""
echo "To run a task:"
echo "  goose run --provider ${PROVIDER_NAME} --model \"${MODEL}\" --with-builtin developer -i <task.md>"
echo ""
echo "Or use sera-run.sh (handles server + verification):"
echo "  ${SKILL_DIR}/scripts/sera-run.sh <task.md>"
