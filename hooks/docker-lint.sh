#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Dockerfile Static Analysis (Hadolint)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

files="$(get_target_files "$@")"
dockerfiles=""

is_dockerfile() {
	local file_path="$1"
	local base_name="${file_path##*/}"
	case "$base_name" in
	Dockerfile* | *.dockerfile | *Dockerfile) return 0 ;;
	esac

	if [ -f "$file_path" ] && head -n 5 "$file_path" 2>/dev/null | grep -Eq '^[[:space:]]*FROM[[:space:]]+'; then
		return 0
	fi
	return 1
}

for file_path in $files; do
	if [ -f "$file_path" ] && is_dockerfile "$file_path"; then
		dockerfiles="$dockerfiles $file_path"
	fi
done

[ -z "$dockerfiles" ] && exit 0

echo "=== Running Dockerfile Lint (Hadolint) ==="

HADOLINT_CMD="$(find_tool hadolint || true)"

if [ -n "$HADOLINT_CMD" ]; then
	# shellcheck disable=SC2086
	"$HADOLINT_CMD" $dockerfiles
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	status=0
	for df in $dockerfiles; do
		echo "  Linting via container: $df"
		if ! docker run --rm -i hadolint/hadolint hadolint - <"$df"; then
			status=1
		fi
	done
	exit $status
elif command -v podman >/dev/null 2>&1; then
	status=0
	for df in $dockerfiles; do
		echo "  Linting via container: $df"
		if ! podman run --rm -i docker.io/hadolint/hadolint hadolint - <"$df"; then
			status=1
		fi
	done
	exit $status
else
	HADOLINT_INSTALL_MSG=$(printf "hadolint binary or container runtime (docker/podman) is required.\n       Install via: curl -sL https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 -o ~/.local/bin/hadolint && chmod +x ~/.local/bin/hadolint")
	require_tool hadolint "$HADOLINT_INSTALL_MSG"
fi
