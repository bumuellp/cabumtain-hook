#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
	files="$*"
else
	files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
fi

shell_files=""

is_shell_script() {
	file_path="$1"
	case "$file_path" in
	*.sh | *.bash) return 0 ;;
	esac

	if [ -f "$file_path" ] && head -n 1 "$file_path" 2>/dev/null | grep -Eq '^#!.*/(env +)?(ba)?sh'; then
		return 0
	fi
	return 1
}

for file_path in $files; do
	if [ -f "$file_path" ] && is_shell_script "$file_path"; then
		shell_files="$shell_files $file_path"
	fi
done

[ -z "$shell_files" ] && exit 0

# Determine shfmt command
SHFMT_CMD=""
if command -v shfmt >/dev/null 2>&1; then
	SHFMT_CMD="shfmt"
elif [ -x "$HOME/.local/bin/shfmt" ]; then
	SHFMT_CMD="$HOME/.local/bin/shfmt"
fi

if [ -n "$SHFMT_CMD" ]; then
	# shellcheck disable=SC2086
	"$SHFMT_CMD" -w $shell_files
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		for file_path in $shell_files; do
			git add "$file_path" 2>/dev/null || true
		done
	fi
fi

# Determine shellcheck command
SHELLCHECK_CMD=""
if command -v shellcheck >/dev/null 2>&1; then
	SHELLCHECK_CMD="shellcheck"
elif [ -x "$HOME/.local/bin/shellcheck" ]; then
	SHELLCHECK_CMD="$HOME/.local/bin/shellcheck"
fi

if [ -n "$SHELLCHECK_CMD" ]; then
	# shellcheck disable=SC2086
	"$SHELLCHECK_CMD" $shell_files
fi
