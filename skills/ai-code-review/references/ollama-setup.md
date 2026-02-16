# Ollama Setup for AI Code Review

## Installation

### macOS

```bash
brew install ollama
```

### Linux

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Windows

Download from https://ollama.ai/download

## Starting Ollama

```bash
# Start server (runs in background)
ollama serve

# Or run as service (macOS)
brew services start ollama
```

Verify running:
```bash
curl http://localhost:11434/api/tags
```

## Downloading Models

### Recommended Models for Code Review

```bash
# OLMo - Good for spec compliance (smaller, faster)
ollama pull olmo

# Gemma 3 - Good for code quality review
ollama pull gemma3

# CodeLlama - Code-specific (larger, slower)
ollama pull codellama

# Llama 3 - General purpose
ollama pull llama3
```

### Check Available Models

```bash
ollama list
```

## Testing Models

```bash
# Quick test
ollama run olmo "What is 2+2?"

# Code review test
ollama run gemma3 "Review this code for bugs: function add(a,b) { return a - b; }"
```

## Configuration

### Memory Settings

For larger models, increase memory:

```bash
# Set memory limit (default is 4GB)
OLLAMA_MAX_MEMORY=8g ollama serve
```

### GPU Acceleration

Ollama automatically uses GPU if available. Check:

```bash
ollama run olmo --verbose "test" 2>&1 | grep -i gpu
```

## Troubleshooting

### "Connection refused"

```bash
# Start Ollama
ollama serve

# Check if running
pgrep ollama
```

### "Model not found"

```bash
# Download the model
ollama pull olmo

# List available
ollama list
```

### Slow responses

- Use smaller model (olmo vs codellama)
- Ensure GPU is being used
- Increase memory allocation
- Consider running on dedicated machine

## Integration Script

Create `scripts/ai-review.sh`:

```bash
#!/bin/bash
set -e

# Check Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Starting Ollama..."
    ollama serve &
    sleep 3
fi

# Get diff
DIFF=$(git diff main)

if [ -z "$DIFF" ]; then
    echo "No changes to review"
    exit 0
fi

echo "🤖 Running AI Code Review..."
echo ""

# Spec compliance review
echo "📋 Spec Compliance (OLMo)..."
echo "$DIFF" | ollama run olmo "Review this diff for completeness and correctness. Report any bugs, missing error handling, or logic issues. Be concise."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Code quality review  
echo "🔍 Code Quality (Gemma)..."
echo "$DIFF" | ollama run gemma3 "Review this code diff for: 1) Bugs 2) Security issues 3) Performance problems. Only report actual issues, not style preferences. Be concise."

echo ""
echo "✓ AI Review complete"
```

Make executable:
```bash
chmod +x scripts/ai-review.sh
```
