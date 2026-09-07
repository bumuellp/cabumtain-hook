#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Ansible Playbook Syntax & Static Analysis
# ==============================================================================
set -euo pipefail

# Only run if ansible directory exists
[ ! -d "ansible" ] && exit 0

if command -v ansible-playbook >/dev/null 2>&1; then
	echo "=== Running Ansible Syntax Validation ==="
	inventory_arg=()
	if [ -f "ansible/inventory.example.ini" ]; then
		inventory_arg=(-i ansible/inventory.example.ini)
	elif [ -f "ansible/inventory.ini" ]; then
		inventory_arg=(-i ansible/inventory.ini)
	fi

	for playbook in ansible/*.yml ansible/*.yaml; do
		if [ -f "$playbook" ]; then
			ansible-playbook "${inventory_arg[@]}" "$playbook" --syntax-check >/dev/null
			echo "  [✓] Syntax valid: $playbook"
		fi
	done
else
	echo "Notice: ansible-playbook not found. Skipping Ansible syntax check."
fi

if command -v ansible-lint >/dev/null 2>&1; then
	echo "=== Running ansible-lint ==="
	ansible-lint ansible/
fi
