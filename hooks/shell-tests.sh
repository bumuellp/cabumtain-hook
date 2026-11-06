#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Shell Unit Tests (Bats)
# Discovers and executes .bats test files under tests/ or test/.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

BATS_VERSION="${BATS_VERSION:-v1.13.0}"

bats_files=()
for search_dir in tests test; do
	if [ -d "$search_dir" ]; then
		while IFS= read -r -d '' file_path; do
			bats_files+=("$file_path")
		done < <(find "$search_dir" -type f -name "*.bats" -print0 2>/dev/null | sort -z)
	fi
done

[ "${#bats_files[@]}" -eq 0 ] && exit 0

echo "=== Running Shell Unit Tests (Bats) ==="

BATS_CMD="$(find_tool bats || true)"

# Auto-bootstrap bats-core into user cache if not installed on host/container
if [ -z "$BATS_CMD" ]; then
	CACHE_ROOT="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/cabumtain-bats/${BATS_VERSION}"
	CACHED_BATS="${CACHE_ROOT}/bin/bats"
	if [ -x "$CACHED_BATS" ]; then
		BATS_CMD="$CACHED_BATS"
	elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
		log_info "Bootstrapping bats-core (${BATS_VERSION}) into ${CACHE_ROOT}..."
		TMP_ARCHIVE="$(mktemp -d)"
		if curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/${BATS_VERSION}.tar.gz" |
			tar -xz -C "$TMP_ARCHIVE" --strip-components=1 2>/dev/null; then
			mkdir -p "$CACHE_ROOT"
			"$TMP_ARCHIVE/install.sh" "$CACHE_ROOT" >/dev/null 2>&1 || true
		fi
		rm -rf "$TMP_ARCHIVE"
		if [ -x "$CACHED_BATS" ]; then
			BATS_CMD="$CACHED_BATS"
		fi
	fi
fi

if [ -z "$BATS_CMD" ]; then
	log_warn "bats not found in PATH and could not be bootstrapped. Skipping Bats unit tests."
	exit 0
fi

"$BATS_CMD" "${bats_files[@]}"
