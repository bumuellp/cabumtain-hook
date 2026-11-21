#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: AI Slop Scanner (aislop)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

# Ensure HOME is writable (aislop creates ~/.aislop on first run)
if [ -z "${HOME:-}" ] || [ ! -w "${HOME}" ]; then
    export HOME="/tmp"
fi

AISLOP_ARGS=("$@")
if [ "${#AISLOP_ARGS[@]}" -eq 0 ]; then
    AISLOP_ARGS=(scan --staged)
fi

aislop_cmd=""
if [ -x "./node_modules/.bin/aislop" ]; then
    aislop_cmd="./node_modules/.bin/aislop"
else
    aislop_cmd="$(find_tool aislop || true)"
fi

if [ -n "$aislop_cmd" ]; then
    exec "$aislop_cmd" "${AISLOP_ARGS[@]}"
fi

npx_cmd="$(find_tool npx || true)"
if [ -n "$npx_cmd" ]; then
    exec "$npx_cmd" --yes "aislop@${AISLOP_VERSION:-^0.16.1}" "${AISLOP_ARGS[@]}"
fi

require_tool aislop "aislop (or npx) is required. Install via: npm install -g aislop"
