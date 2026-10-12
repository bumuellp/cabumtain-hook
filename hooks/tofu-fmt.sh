#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

tofu_files=()

is_tofu_file() {
	local file_path="$1"
	case "$file_path" in
	*.tf | *.tofu | *.tfvars) return 0 ;;
	esac
	return 1
}

while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	if [ -f "$file_path" ] && is_tofu_file "$file_path"; then
		tofu_files+=("$file_path")
	fi
done < <(get_target_files "$@")

[ "${#tofu_files[@]}" -eq 0 ] && exit 0

TOFU_CMD="$(find_tool tofu || find_tool terraform || true)"
if [ -z "$TOFU_CMD" ]; then
	log_warn "Neither 'tofu' nor 'terraform' was found in PATH. Skipping tofu format check."
	exit 0
fi

"$TOFU_CMD" fmt "${tofu_files[@]}"
