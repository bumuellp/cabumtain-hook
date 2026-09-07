#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
	files="$*"
else
	files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
fi

yaml_files=""
xml_files=""

for file_path in $files; do
	case "$file_path" in
	*.enc.yml | *.enc.yaml)
		# Skip encrypted SOPS secrets
		;;
	*.yml | *.yaml)
		[ -f "$file_path" ] && yaml_files="$yaml_files $file_path"
		;;
	*.xml)
		[ -f "$file_path" ] && xml_files="$xml_files $file_path"
		;;
	esac
done

if [ -n "$yaml_files" ]; then
	YAMLLINT_CMD=""
	if command -v yamllint >/dev/null 2>&1; then
		YAMLLINT_CMD="yamllint"
	elif [ -x "$HOME/.local/bin/yamllint" ]; then
		YAMLLINT_CMD="$HOME/.local/bin/yamllint"
	fi

	if [ -n "$YAMLLINT_CMD" ]; then
		if [ -f ".yamllint.yml" ] || [ -f ".yamllint.yaml" ] || [ -f ".yamllint" ]; then
			# shellcheck disable=SC2086
			"$YAMLLINT_CMD" $yaml_files
		else
			# Fallback to relaxed config if no custom config in repository
			# shellcheck disable=SC2086
			"$YAMLLINT_CMD" -d "{extends: relaxed, rules: {line-length: disable}}" $yaml_files
		fi
	else
		echo "ERROR: yamllint is required to lint staged YAML files." >&2
		exit 1
	fi
fi

if [ -n "$xml_files" ]; then
	if command -v xmllint >/dev/null 2>&1; then
		for file_path in $xml_files; do
			xmllint --noout "$file_path"
		done
	elif command -v python3 >/dev/null 2>&1; then
		# shellcheck disable=SC2086
		python3 - $xml_files <<'PY'
import sys
import xml.etree.ElementTree as ET

failed = False
for path in sys.argv[1:]:
    try:
        ET.parse(path)
    except Exception as exc:
        failed = True
        print(f"XML lint failed for {path}: {exc}", file=sys.stderr)

if failed:
    sys.exit(1)
PY
	fi
fi
