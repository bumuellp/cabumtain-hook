#!/bin/sh
set -eu

if [ "${OS:-}" = "Windows_NT" ]; then
	echo "WARN: Skipping pre-commit lint checks on Windows due Git-for-Windows shell fork limitation." >&2
	echo "Run checks manually in Git Bash/WSL or CI will enforce them." >&2
	exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

checks="
secret-scan.sh
shell-lint.sh
ansible-lint.sh
yaml-xml-lint.sh
python-tests.sh
k8s-validate.sh
trivy-security.sh
"

for check_script in $checks; do
	target="$SCRIPT_DIR/$check_script"
	if [ -f "$target" ] && [ -x "$target" ]; then
		if ! "$target"; then
			echo "" >&2
			echo "ERROR: pre-commit check failed at $check_script" >&2
			exit 1
		fi
	fi
done
