#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

rust_files=()

is_rust_file() {
	local file_path="$1"
	case "$file_path" in
	*.rs | Cargo.toml | Cargo.lock | */Cargo.toml | */Cargo.lock) return 0 ;;
	esac
	return 1
}

while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	if [ -f "$file_path" ] && is_rust_file "$file_path"; then
		rust_files+=("$file_path")
	fi
done < <(get_target_files "$@")

[ "${#rust_files[@]}" -eq 0 ] && exit 0

CARGO_CMD="$(find_tool cargo || true)"
RUSTFMT_CMD="$(find_tool rustfmt || true)"

if [ -z "$CARGO_CMD" ] && [ -z "$RUSTFMT_CMD" ]; then
	log_warn "Neither 'cargo' nor 'rustfmt' was found in PATH. Skipping Rust linting."
	exit 0
fi

# Locate all unique Cargo.toml manifest files associated with changed files
declare -A cargo_manifests=()
for file in "${rust_files[@]}"; do
	dir="$(dirname "$file")"
	while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
		if [ -f "$dir/Cargo.toml" ]; then
			cargo_manifests["$dir/Cargo.toml"]=1
			break
		fi
		dir="$(dirname "$dir")"
	done
	if [ -f "Cargo.toml" ]; then
		cargo_manifests["Cargo.toml"]=1
	fi
done

# Format check with rustfmt / cargo fmt (strictly check-only; no file modification)
if [ -n "$CARGO_CMD" ] && [ "${#cargo_manifests[@]}" -gt 0 ]; then
	for manifest in "${!cargo_manifests[@]}"; do
		if [ -f "$manifest" ]; then
			manifest_dir="$(dirname "$manifest")"
			if ! (cd "$manifest_dir" && "$CARGO_CMD" fmt --check); then
				log_error "Formatting check failed in $manifest_dir. Run 'cargo fmt' to format."
				exit 1
			fi
		fi
	done
elif [ -n "$RUSTFMT_CMD" ]; then
	for file in "${rust_files[@]}"; do
		if [[ "$file" == *.rs ]]; then
			if ! "$RUSTFMT_CMD" --check "$file"; then
				log_error "Formatting check failed for $file. Run 'rustfmt $file' to format."
				exit 1
			fi
		fi
	done
fi

# Check if cargo-clippy is available
HAS_CLIPPY=false
if [ -n "$CARGO_CMD" ] && "$CARGO_CMD" clippy --version >/dev/null 2>&1; then
	HAS_CLIPPY=true
fi

# Run cargo clippy / cargo check for each discovered manifest
if [ -n "$CARGO_CMD" ] && [ "${#cargo_manifests[@]}" -gt 0 ]; then
	for manifest in "${!cargo_manifests[@]}"; do
		if [ -f "$manifest" ]; then
			if [ "$HAS_CLIPPY" = "true" ]; then
				log_info "Running cargo clippy on: $manifest"
				"$CARGO_CMD" clippy --manifest-path "$manifest" --all-targets -- -D warnings
			else
				log_info "Running cargo check on: $manifest"
				"$CARGO_CMD" check --manifest-path "$manifest" --all-targets
			fi
		fi
	done
fi
