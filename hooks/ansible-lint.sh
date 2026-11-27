#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: Ansible Playbook & Collection Syntax / Static Analysis
# ==============================================================================
set -euo pipefail

run_playbook_checks() {
    local inventory_arg=()
    if [ -f "ansible/inventory.example.ini" ]; then
        inventory_arg=(-i ansible/inventory.example.ini)
    elif [ -f "ansible/inventory.ini" ]; then
        inventory_arg=(-i ansible/inventory.ini)
    fi

    if command -v ansible-playbook >/dev/null 2>&1; then
        echo "=== Running Ansible Syntax Validation ==="
        for playbook in ansible/*.yml ansible/*.yaml; do
            [ -f "$playbook" ] || continue
            case "$(basename "$playbook")" in
            requirements.yml | requirements.yaml | galaxy.yml | galaxy.yaml)
                continue
                ;;
            esac
            ansible-playbook "${inventory_arg[@]}" "$playbook" --syntax-check >/dev/null
            echo "  [✓] Syntax valid: $playbook"
        done
    else
        echo "Notice: ansible-playbook not found. Skipping Ansible syntax check."
    fi

    if command -v ansible-lint >/dev/null 2>&1; then
        echo "=== Running ansible-lint ==="
        ansible-lint ansible/
    fi
}

run_collection_checks() {
    if command -v ansible-lint >/dev/null 2>&1; then
        echo "=== Running ansible-lint (collection) ==="
        ansible-lint
    else
        echo "Notice: ansible-lint not found. Skipping collection lint."
    fi
}

if [ -d "ansible" ]; then
    run_playbook_checks
elif [ -f "galaxy.yml" ] || [ -f "galaxy.yaml" ]; then
    run_collection_checks
fi
