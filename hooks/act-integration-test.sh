#!/usr/bin/env bash
# ==============================================================================
# Git Hook: Local GitHub Actions Integration Testing with act (Pre-Push)
# ==============================================================================
set -euo pipefail

# 1. CI Recursion Guard: Never execute nested act inside GitHub Actions runners
if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
	echo "Notice: Running inside GitHub Actions CI. Skipping local act runner."
	exit 0
fi

# 2. Tool Discovery: Detect native act binary or gh act extension
ACT_CMD=""
if command -v act >/dev/null 2>&1; then
	ACT_CMD="act"
elif command -v gh >/dev/null 2>&1 && gh extension list 2>/dev/null | grep -q "nektos/gh-act"; then
	ACT_CMD="gh act"
else
	echo "❌ [act-integration-test] Failed: 'act' is required for pre-push integration testing." >&2
	echo "Install native act via: curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash" >&2
	exit 1
fi

# 3. Docker Daemon Check: act requires access to Docker daemon
if ! docker info >/dev/null 2>&1; then
	echo "❌ [act-integration-test] Failed: Docker daemon is not running or inaccessible." >&2
	echo "Ensure Docker is started before running integration tests." >&2
	exit 1
fi

# 4. Passthrough arguments if provided via pre-commit args
if [ "$#" -gt 0 ]; then
	echo "=== Running act with custom arguments: $* ==="
	exec "$ACT_CMD" "$@"
fi

# 5. Workflow Resolution: Check ACT_WORKFLOW or discover integration test workflows
WORKFLOW_TARGET=()
if [ -n "${ACT_WORKFLOW:-}" ]; then
	if [ -f "$ACT_WORKFLOW" ]; then
		WORKFLOW_TARGET=("-W" "$ACT_WORKFLOW")
	else
		echo "❌ [act-integration-test] Failed: ACT_WORKFLOW='$ACT_WORKFLOW' file not found!" >&2
		exit 1
	fi
else
	shopt -s nullglob
	discovered=(.github/workflows/*integration*.yml .github/workflows/*integration*.yaml .github/workflows/*test*.yml .github/workflows/*test*.yaml)
	shopt -u nullglob

	if [ ${#discovered[@]} -gt 0 ]; then
		WORKFLOW_TARGET=("-W" "${discovered[0]}")
	else
		echo "❌ [act-integration-test] Failed: No integration test workflow found!" >&2
		echo "" >&2
		echo "The hook 'act-integration-test' is enabled in .pre-commit-config.yaml, but no matching workflow was detected." >&2
		echo "Expected a workflow matching '.github/workflows/*integration*.yml' or specified via args:" >&2
		echo "  - id: act-integration-test" >&2
		echo "    args: [-W, .github/workflows/my-custom-test.yml]" >&2
		echo "If this repository does not use local integration tests, remove 'act-integration-test' from .pre-commit-config.yaml." >&2
		exit 1
	fi
fi

echo "=== Running Integration Tests via $ACT_CMD (${WORKFLOW_TARGET[*]}) ==="
exec "$ACT_CMD" "${WORKFLOW_TARGET[@]}"
