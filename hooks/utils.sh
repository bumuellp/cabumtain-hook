#!/usr/bin/env bash
# ==============================================================================
# Shared utility functions for cabumtain-hook scripts
# ==============================================================================

log_info() {
	echo "INFO: $*"
}

log_warn() {
	echo "WARN: $*" >&2
}

log_error() {
	echo "ERROR: $*" >&2
}

find_tool() {
	local name="$1"
	if command -v "$name" >/dev/null 2>&1; then
		echo "$name"
		return 0
	elif [ -x "$HOME/.local/bin/$name" ]; then
		echo "$HOME/.local/bin/$name"
		return 0
	fi
	return 1
}

require_tool() {
	local name="$1"
	local desc="${2:-$name is required}"
	local tool
	if tool="$(find_tool "$name")"; then
		echo "$tool"
		return 0
	else
		echo "ERROR: $desc" >&2
		exit 1
	fi
}

get_target_files() {
	if [ "$#" -gt 0 ]; then
		echo "$*"
	else
		git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true
	fi
}
