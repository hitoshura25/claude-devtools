# SERA Model Limitations

## Language Support

**Validated:** Python only

SERA was trained and evaluated exclusively on Python repositories. Using it for other languages may produce:
- Incorrect idioms
- Suboptimal patterns
- Syntax errors

## Context Window

**Limit:** 32,768 tokens (~24K words)

Plan for this by:
- Providing focused context (not entire codebase)
- Chunking large implementations into smaller tasks
- Including only relevant code snippets

## Teacher Model Ceiling

SERA is teacher-bounded by GLM-4.6, meaning it cannot exceed GLM-4.6's capabilities:
- May struggle with cutting-edge patterns
- Limited knowledge of libraries released after training
- May not know newest Python 3.12+ features

## Safety Filtering

SERA has minimal built-in safety filtering. Always:
- Review generated code before committing
- Run security scans on output
- Don't use for security-critical code without review

## Tool Calling

SERA's tool calling may differ from Claude Code's expectations. When using with Goose:
- Prefer text-based instructions over tool invocations
- Be explicit about expected output format
- Consider sera-cli for better SERA-specific handling

## Memory and Performance

- **RAM:** Requires ~24GB available
- **Inference:** Slower than cloud models (local GPU)
- **Cold start:** First request after loading takes longer

## Known Issues

1. **Long outputs:** May truncate at 4K tokens by default
2. **Complex nesting:** Can lose track in deeply nested structures
3. **Multi-file changes:** Works best on single-file tasks

## Mitigation Strategies

| Limitation | Mitigation |
|------------|------------|
| Python only | Use Claude for non-Python |
| 32K context | Chunk tasks, focused context |
| Tool calling | Use sera-cli or text instructions |
| Safety | Review all output, run security scans |
