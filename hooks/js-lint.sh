#!/usr/bin/env bash
# ==============================================================================
# Git Pre-Commit Hook: JavaScript & TypeScript Lint (Oxlint)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

js_files=()

is_js_ts_file() {
    local file_path="$1"
    case "$file_path" in
    node_modules/* | */node_modules/* | dist/* | */dist/* | build/* | */build/* | coverage/* | */coverage/*)
        return 1
        ;;
    *.js | *.jsx | *.mjs | *.cjs | *.ts | *.tsx | *.mts | *.cts)
        return 0
        ;;
    esac
    return 1
}

find_project_root() {
    local file_path="$1"
    local dir
    dir="$(dirname "$file_path")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -f "$dir/.oxlintrc.json" ] || [ -f "$dir/oxlint.config.ts" ] || [ -f "$dir/oxlint.config.mjs" ] || [ -f "$dir/package.json" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    printf '%s\n' "."
}

while IFS= read -r -d '' file_path; do
    [ -z "$file_path" ] && continue
    if [ -f "$file_path" ] && is_js_ts_file "$file_path"; then
        js_files+=("$file_path")
    fi
done < <(get_target_files "$@")

[ "${#js_files[@]}" -eq 0 ] && exit 0

declare -A seen_projects=()
project_roots=()
file_projects=()

for file_path in "${js_files[@]}"; do
    proj="$(find_project_root "$file_path")"
    file_projects+=("$proj")
    if [ -z "${seen_projects[$proj]+x}" ]; then
        seen_projects["$proj"]=1
        project_roots+=("$proj")
    fi
done

EXTRA_ARGS=()
if [ -n "${OXLINT_ARGS:-}" ]; then
    read -r -a EXTRA_ARGS <<<"$OXLINT_ARGS"
fi

status=0
for proj in "${project_roots[@]}"; do
    oxlint_cmd=""
    if [ -x "$proj/node_modules/.bin/oxlint" ]; then
        oxlint_cmd="$proj/node_modules/.bin/oxlint"
    else
        oxlint_cmd="$(find_tool oxlint || true)"
    fi

    if [ -z "$oxlint_cmd" ]; then
        OXLINT_INSTALL_MSG=$(printf "oxlint is required to lint JavaScript/TypeScript files.\n       Install via: npm install -D oxlint (or mise use -g oxlint)")
        require_tool oxlint "$OXLINT_INSTALL_MSG"
    fi

    # Resolve absolute path so subshell cd to $proj never breaks relative command paths
    if [[ "$oxlint_cmd" == */* ]] && [[ "$oxlint_cmd" != /* ]]; then
        oxlint_cmd="$(cd "$(dirname "$oxlint_cmd")" && pwd)/$(basename "$oxlint_cmd")"
    fi

    cmd_args=()
    if [ "${OXLINT_TYPE_AWARE:-false}" = "true" ] || [ -x "$proj/node_modules/.bin/tsgolint" ] || [ -d "$proj/node_modules/oxlint-tsgolint" ]; then
        cmd_args+=("--type-aware")
    fi
    if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
        cmd_args+=("${EXTRA_ARGS[@]}")
    fi

    rel_files=()
    proj_prefix="${proj%/}/"
    for i in "${!js_files[@]}"; do
        if [ "${file_projects[$i]}" = "$proj" ]; then
            f="${js_files[$i]}"
            if [ "$proj" != "." ]; then
                f="${f#"$proj_prefix"}"
            fi
            rel_files+=("$f")
        fi
    done

    echo "=== Running JS/TS Lint (Oxlint) in ${proj} ==="
    if ! (cd "$proj" && "$oxlint_cmd" ${cmd_args[@]+"${cmd_args[@]}"} "${rel_files[@]}"); then
        status=1
    fi
done

exit "$status"
