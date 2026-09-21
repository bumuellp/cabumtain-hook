#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Dockerfile Static Analysis (Hadolint)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

dockerfiles=()

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

while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	if [ -f "$file_path" ] && is_dockerfile "$file_path"; then
		dockerfiles+=("$file_path")
	fi
done < <(get_target_files "$@")

[ "${#dockerfiles[@]}" -eq 0 ] && exit 0

echo "=== Running Dockerfile Lint (Hadolint) ==="

HADOLINT_CMD="$(find_tool hadolint || true)"
CONTAINER_RUNTIME=""
CONTAINER_IMAGE="docker.io/hadolint/hadolint:v2.12.0"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	CONTAINER_RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
	CONTAINER_RUNTIME="podman"
fi

if [ -n "$HADOLINT_CMD" ]; then
	"$HADOLINT_CMD" "${dockerfiles[@]}"
elif [ -n "$CONTAINER_RUNTIME" ]; then
	status=0
	for df in "${dockerfiles[@]}"; do
		echo "  Linting via container ($CONTAINER_RUNTIME): $df"
		if ! "$CONTAINER_RUNTIME" run --rm -i "$CONTAINER_IMAGE" hadolint - <"$df"; then
			status=1
		fi
	done
	exit $status
else
	HADOLINT_INSTALL_MSG=$(printf "hadolint binary or container runtime (docker/podman) is required.\n       Install via: curl -sL https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 -o ~/.local/bin/hadolint && chmod +x ~/.local/bin/hadolint")
	require_tool hadolint "$HADOLINT_INSTALL_MSG"
fi
