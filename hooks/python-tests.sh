#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Python Unit Tests (pytest / unittest)
# ==============================================================================
set -euo pipefail

if [ -d "tests" ]; then
	echo "=== Running Python Unit Tests ==="
	if command -v pytest >/dev/null 2>&1; then
		pytest tests/ -q
	elif [ -x "$HOME/.local/bin/pytest" ]; then
		"$HOME/.local/bin/pytest" tests/ -q
	elif command -v python3 >/dev/null 2>&1; then
		python3 -m unittest discover -s tests -v
	else
		echo "Notice: python3 / pytest not found. Skipping python unit tests."
	fi
fi
