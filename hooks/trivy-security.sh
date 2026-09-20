#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible wrapper delegating to unified trivy.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/trivy.sh" --mode=config "$@"
