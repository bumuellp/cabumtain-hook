#!/usr/bin/env bash
# ==============================================================================
# Shared utility functions for cabumtain-hook scripts
# ==============================================================================

log_info() {
    echo "INFO: $*"
}

log_warn() {
    echo "WARN: $*" >&2
}

log_error() {
    echo "ERROR: $*" >&2
}

_mise_spec_for_tool() {
    local name="$1"
    local repo_root
    repo_root="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
    local mise_file="${repo_root}/mise.toml"
    [ -f "$mise_file" ] || return 1

    local key="$name"
    case "$name" in
    tofu) key="opentofu" ;;
    yamllint | pytest | ansible-lint) key="pipx:${name}" ;;
    ansible-playbook) key="pipx:ansible-core" ;;
    esac

    local ver
    ver="$(awk -F'=' -v k="$key" '
        $0 ~ "^[[:space:]]*\"?" k "\"?[[:space:]]*=" {
            v = $2
            gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", v)
            print v
            exit
        }
    ' "$mise_file")"
    [ -n "$ver" ] || return 1
    printf '%s@%s' "$key" "$ver"
}

find_tool() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        echo "$name"
        return 0
    elif [ -x "$HOME/.local/bin/$name" ]; then
        echo "$HOME/.local/bin/$name"
        return 0
    elif [ "${CI:-false}" = "true" ] || [ "${CABUMTAIN_AUTO_INSTALL:-false}" = "true" ]; then
        if command -v mise >/dev/null 2>&1; then
            local spec bin_path
            if spec="$(_mise_spec_for_tool "$name")"; then
                if [[ "$spec" == pipx:* ]] && ! command -v uv >/dev/null 2>&1; then
                    local uv_spec
                    if uv_spec="$(_mise_spec_for_tool uv)"; then
                        mise use --global --yes "$uv_spec" >/dev/null 2>&1 || true
                    fi
                fi
                mise use --global --yes "$spec" >/dev/null 2>&1 || true
                bin_path="$(mise which "$name" 2>/dev/null || true)"
                if [ -n "$bin_path" ] && [ -x "$bin_path" ]; then
                    echo "$bin_path"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

require_tool() {
    local name="$1"
    local desc="${2:-$name is required}"
    local tool
    if tool="$(find_tool "$name")"; then
        echo "$tool"
        return 0
    else
        echo "ERROR: $desc" >&2
        exit 1
    fi
}

get_target_files() {
    if [ "$#" -gt 0 ]; then
        printf '%s\0' "$@"
    else
        git diff --cached -z --name-only --diff-filter=ACMR 2>/dev/null || true
    fi
}
