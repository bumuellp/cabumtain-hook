#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Python Unit Tests (pytest / unittest)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/utils.sh"

if [ -d "tests" ]; then
    echo "=== Running Python Unit Tests ==="
    UV_CMD="$(find_tool uv || true)"
    if [ -n "$UV_CMD" ] && [ -f "pyproject.toml" ]; then
        "$UV_CMD" run pytest tests/ -q
    elif [ -x ".venv/bin/pytest" ]; then
        .venv/bin/pytest tests/ -q
    else
        PYTEST_CMD="$(find_tool pytest || true)"
        if [ -n "$PYTEST_CMD" ]; then
            "$PYTEST_CMD" tests/ -q
        elif command -v python3 >/dev/null 2>&1; then
            python3 -m unittest discover -s tests -v
        else
            echo "Notice: python3 / pytest / uv not found. Skipping python unit tests."
        fi
    fi
fi
