#!/bin/bash
# SERA MLX Server Management
# Uses mlx-openai-server for proper tool calling support
# Usage: sera-server.sh [start|stop|status|restart|logs|test]

set -e

MODEL="hitoshura25/SERA-32B-mlx-4Bit"
PORT=8080
PID_FILE="/tmp/sera-mlx-server.pid"
LOG_FILE="/tmp/sera-mlx-server.log"

# Virtual environment created by setup.sh with Python 3.12
SERA_VENV="${HOME}/.sera-venv"

# Check venv exists
check_venv() {
    if [[ ! -d "$SERA_VENV" ]]; then
        echo "❌ SERA virtual environment not found at ${SERA_VENV}"
        echo "Run setup.sh first to create it"
        exit 1
    fi
    
    if [[ ! -f "${SERA_VENV}/bin/mlx-openai-server" ]]; then
        echo "❌ mlx-openai-server not installed in venv"
        echo "Run setup.sh to install dependencies"
        exit 1
    fi
}

status() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" &>/dev/null; then
            echo "✅ SERA server running (PID: $PID)"
            # Verify it's responding
            if curl -s "http://localhost:${PORT}/v1/models" &>/dev/null; then
                echo "✅ Server responding on port $PORT"
                return 0
            else
                echo "⚠️  Server process exists but not responding"
                return 1
            fi
        fi
    fi
    echo "❌ SERA server not running"
    return 1
}

start() {
    check_venv
    
    if status &>/dev/null; then
        echo "Server already running"
        return 0
    fi

    echo "Starting SERA MLX server..."
    echo "Model: $MODEL"
    echo "Port: $PORT"
    echo "Venv: $SERA_VENV"
    echo "Log: $LOG_FILE"
    echo ""

    # Start mlx-openai-server from venv in background
    # SERA is Qwen3-based, needs qwen3 parsers for tool calling and reasoning
    # --enable-auto-tool-choice: Required for automatic tool selection
    # --tool-call-parser qwen3: Parse <tool_call> tags in Qwen3 format
    # --reasoning-parser qwen3: Parse <think> tags (reasoning/thinking blocks)
    # Requires mlx-openai-server >= 1.5.0
    nohup "${SERA_VENV}/bin/mlx-openai-server" launch \
        --log-level debug \
        --model-path "$MODEL" \
        --model-type lm \
        --enable-auto-tool-choice \
        --tool-call-parser qwen3 \
        --reasoning-parser qwen3 \
        --port "$PORT" \
        > "$LOG_FILE" 2>&1 &

    echo $! > "$PID_FILE"

    # Wait for server to be ready
    echo "Waiting for server to initialize (loading ~24GB model)..."
    for i in {1..120}; do
        if curl -s "http://localhost:${PORT}/v1/models" &>/dev/null; then
            echo ""
            echo "✅ SERA server started successfully"
            echo ""
            echo "API endpoint: http://localhost:${PORT}/v1"
            return 0
        fi
        printf "."
        sleep 2
    done

    echo ""
    echo "❌ Server failed to start within 240 seconds"
    echo "Check log: tail -f $LOG_FILE"
    return 1
}

stop() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" &>/dev/null; then
            echo "Stopping SERA server (PID: $PID)..."
            kill "$PID"
            rm -f "$PID_FILE"
            echo "✅ Server stopped (freed ~24GB RAM)"
            return 0
        fi
    fi
    echo "Server not running"
    rm -f "$PID_FILE"
}

restart() {
    stop
    sleep 2
    start
}

logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        echo "No log file found at $LOG_FILE"
    fi
}

test_completion() {
    echo "Testing completion with model: $MODEL"
    echo ""
    
    response=$(curl -s "http://localhost:${PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"What is 2 + 2? Reply with just the number.\"}],
            \"max_tokens\": 50
        }")
    
    echo "Response:"
    echo "$response" | python -m json.tool 2>/dev/null || echo "$response"
}

case "${1:-status}" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    logs)    logs ;;
    test)    test_completion ;;
    *)
        echo "Usage: sera-server.sh [start|stop|restart|status|logs|test]"
        exit 1
        ;;
esac
