# Goose Provider Configuration

## Option 1: JSON Config File (Recommended)

Create `~/.config/goose/custom_providers/sera_mlx.json`:

```json
{
  "name": "sera_mlx",
  "engine": "openai",
  "display_name": "SERA MLX Local",
  "description": "Local SERA-32B via MLX server for Python implementation tasks",
  "api_key_env": "SERA_API_KEY",
  "base_url": "http://localhost:8080/v1/chat/completions",
  "models": [
    {
      "name": "hitoshura25/SERA-32B-mlx-4Bit",
      "context_limit": 32000
    }
  ],
  "supports_streaming": true
}
```

Set environment variable (MLX doesn't require auth, but Goose needs a value):
```bash
export SERA_API_KEY="local"
```

## Option 2: CLI Configuration

```bash
goose configure
# Select: Custom Providers → Add A Custom Provider
# API Type: OpenAI Compatible
# Name: sera_mlx
# API URL: http://localhost:8080/v1/chat/completions
# API Key: local
# Available Models: hitoshura25/SERA-32B-mlx-4Bit
# Streaming Support: Yes
```

## Verifying Configuration

```bash
# List providers
goose configure --list-providers

# Test connection
goose run --provider sera_mlx -t "Say hello"
```

## Using with Goose

**One-shot execution:**
```bash
goose run --provider sera_mlx -t "your task here"
```

**Interactive session:**
```bash
goose session start --provider sera_mlx
```

**With file input:**
```bash
goose run --provider sera_mlx -i task-context.md
```

## Adding Other Models

To add Codestral or other models, create additional JSON files:

`~/.config/goose/custom_providers/codestral_mlx.json`:
```json
{
  "name": "codestral_mlx",
  "engine": "openai",
  "display_name": "Codestral Local",
  "description": "Local Codestral via MLX for code tasks",
  "api_key_env": "CODESTRAL_API_KEY",
  "base_url": "http://localhost:8080/v1/chat/completions",
  "models": [
    {
      "name": "codestral-22b-v0.1-mlx-4bit",
      "context_limit": 32000
    }
  ],
  "supports_streaming": true
}
```

Switch between providers with `--provider` flag.
