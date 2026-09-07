#!/bin/sh
set -eu

commit_msg_file="${1:-}"
if [ -z "$commit_msg_file" ] || [ ! -f "$commit_msg_file" ]; then
	echo "ERROR: Commit message file not found or not provided." >&2
	exit 1
fi

first_line=""
IFS= read -r first_line <"$commit_msg_file" || true

# Ignore merge, revert, or squash commits
case "$first_line" in
Merge* | Revert* | "fixup!"* | "squash!"*)
	exit 0
	;;
esac

# Validate Conventional Commit format
valid_format=0
case "$first_line" in
feat:\ * | fix:\ * | docs:\ * | chore:\ * | refactor:\ * | test:\ * | ci:\ * | build:\ * | perf:\ * | style:\ * | revert:\ *)
	valid_format=1
	;;
feat\(*\):\ * | fix\(*\):\ * | docs\(*\):\ * | chore\(*\):\ * | refactor\(*\):\ * | test\(*\):\ * | ci\(*\):\ * | build\(*\):\ * | perf\(*\):\ * | style\(*\):\ * | revert\(*\):\ *)
	valid_format=1
	;;
esac

if [ "$valid_format" -ne 1 ]; then
	echo "" >&2
	echo "ERROR: Commit message rejected" >&2
	echo "Expected Conventional Commit format:" >&2
	echo "  <type>(<optional-scope>): <description>" >&2
	echo "" >&2
	echo "Allowed types:" >&2
	echo "  feat, fix, docs, chore, refactor, test, ci, build, perf, style, revert" >&2
	echo "" >&2
	echo "Your first line was:" >&2
	echo "  ${first_line:-<empty>}" >&2
	echo "" >&2
	echo "Examples:" >&2
	echo "  feat(vps): add kong rsync staging guard" >&2
	echo "  fix(ci): normalize deploy script line endings" >&2
	echo "  docs(logging): add cron template for host metrics" >&2
	echo "" >&2
	echo "Tip: in VS Code / IDE Source Control, only the first line is validated by this hook." >&2
	exit 1
fi

# 72 character length recommendation / limit check
line_length=$(printf "%s" "$first_line" | wc -c)
if [ "$line_length" -gt 72 ]; then
	echo "" >&2
	echo "ERROR: Commit message header is too long (${line_length} characters, maximum is 72)." >&2
	echo "Your first line was:" >&2
	echo "  $first_line" >&2
	echo "" >&2
	echo "Please keep the subject concise and place detailed explanations in the commit body." >&2
	exit 1
fi

exit 0
