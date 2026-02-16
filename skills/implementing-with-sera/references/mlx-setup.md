# MLX Server Setup

## Installation

```bash
# Install mlx-lm
pip install mlx-lm

# Download model (18.4GB, one-time)
python -c "from mlx_lm import load; load('hitoshura25/SERA-32B-mlx-4Bit')"
```

## Starting the Server

```bash
python -m mlx_lm.server --model hitoshura25/SERA-32B-mlx-4Bit --port 8080
```

**With custom settings:**
```bash
python -m mlx_lm.server \
  --model hitoshura25/SERA-32B-mlx-4Bit \
  --port 8080 \
  --host 0.0.0.0 \
  --max-tokens 4096
```

## Verifying Server

```bash
# Check health
curl http://localhost:8080/v1/models

# Test completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hitoshura25/SERA-32B-mlx-4Bit",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Out of memory | Close other apps, reduce max_tokens |
| Port in use | Use different port: `--port 8081` |
| Model not found | Re-download: `mlx_lm.load()` |
| Slow inference | Ensure GPU is being used (check Activity Monitor) |

## Resource Requirements

- **RAM:** ~24GB recommended (18.4GB model + overhead)
- **Disk:** ~20GB for model files
- **GPU:** Apple Silicon (M1/M2/M3) with unified memory
