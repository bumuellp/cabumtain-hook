#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Git Pre-Commit Hook: Secrets & Credential Scanner (TruffleHog)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/utils.sh"

TRUFFLEHOG_CMD="$(require_tool trufflehog 'trufflehog is required for secret and credential scanning. Install via: curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b ~/.local/bin')"

# Detect CI vs Local environment
if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
	echo "Running TruffleHog secrets scan in CI..."
	"$TRUFFLEHOG_CMD" git file://. --since-commit HEAD --fail --no-update
else
	# Fast local offline check against staged changes
	echo "Running TruffleHog secrets scan on staged changes..."
	"$TRUFFLEHOG_CMD" git file://. --since-commit HEAD --fail --no-verification --no-update
fi
