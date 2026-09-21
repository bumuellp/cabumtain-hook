#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/utils.sh"

yaml_files=()
xml_files=()

while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	case "$file_path" in
	*.enc.yml | *.enc.yaml)
		# Skip encrypted SOPS secrets
		;;
	*.yml | *.yaml)
		[ -f "$file_path" ] && yaml_files+=("$file_path")
		;;
	*.xml)
		[ -f "$file_path" ] && xml_files+=("$file_path")
		;;
	esac
done < <(get_target_files "$@")

if [ "${#yaml_files[@]}" -gt 0 ]; then
	YAMLLINT_CMD="$(find_tool yamllint || true)"

	if [ -n "$YAMLLINT_CMD" ]; then
		if [ -f ".yamllint.yml" ] || [ -f ".yamllint.yaml" ] || [ -f ".yamllint" ]; then
			"$YAMLLINT_CMD" "${yaml_files[@]}"
		else
			# Fallback to relaxed config if no custom config in repository
			"$YAMLLINT_CMD" -d "{extends: relaxed, rules: {line-length: disable}}" "${yaml_files[@]}"
		fi
	else
		echo "ERROR: yamllint is required to lint staged YAML files." >&2
		exit 1
	fi
fi

if [ "${#xml_files[@]}" -gt 0 ]; then
	if command -v xmllint >/dev/null 2>&1; then
		for file_path in "${xml_files[@]}"; do
			xmllint --noout "$file_path"
		done
	elif command -v python3 >/dev/null 2>&1; then
		python3 - "${xml_files[@]}" <<'PY'
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
