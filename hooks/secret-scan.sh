#!/bin/sh
set -eu

# ==============================================================================
# Git Pre-Commit Hook: Secrets & Credential Scanner (TruffleHog)
# ==============================================================================

TRUFFLEHOG_CMD="trufflehog"
if ! command -v trufflehog >/dev/null 2>&1; then
	if [ -x "$HOME/.local/bin/trufflehog" ]; then
		TRUFFLEHOG_CMD="$HOME/.local/bin/trufflehog"
	else
		echo "INFO: trufflehog not installed, skipping local secret scan." >&2
		echo "      Install via: curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b ~/.local/bin" >&2
		exit 0
	fi
fi

# Detect CI vs Local environment
if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
	echo "Running TruffleHog secrets scan in CI..."
	"$TRUFFLEHOG_CMD" git file://. --since-commit HEAD --fail
else
	# Fast local offline check against staged changes
	echo "Running TruffleHog secrets scan on staged changes..."
	"$TRUFFLEHOG_CMD" git file://. --since-commit HEAD --fail --no-verification
fi
