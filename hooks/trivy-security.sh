#!/bin/sh
set -eu

# Backward-compatible wrapper delegating to unified trivy.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/trivy.sh" --mode=config "$@"
