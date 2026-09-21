#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

shell_files=()

is_shell_script() {
	local file_path="$1"
	case "$file_path" in
	*.sh | *.bash) return 0 ;;
	esac

	if [ -f "$file_path" ] && head -n 1 "$file_path" 2>/dev/null | grep -Eq '^#!.*/(env +)?(ba)?sh'; then
		return 0
	fi
	return 1
}

while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	if [ -f "$file_path" ] && is_shell_script "$file_path"; then
		shell_files+=("$file_path")
	fi
done < <(get_target_files "$@")

[ "${#shell_files[@]}" -eq 0 ] && exit 0

SHFMT_CMD="$(find_tool shfmt || true)"
if [ -n "$SHFMT_CMD" ]; then
	"$SHFMT_CMD" -w "${shell_files[@]}"
fi

SHELLCHECK_CMD="$(find_tool shellcheck || true)"
if [ -n "$SHELLCHECK_CMD" ]; then
	"$SHELLCHECK_CMD" -x "${shell_files[@]}"
fi
