#!/usr/bin/env bash
# ==============================================================================
# Tag Immutability Guard (Pre-Push Hook)
# Blocks mutating or force-overwriting existing SemVer release tags (vX.Y.Z).
# ==============================================================================
set -euo pipefail

REMOTE="${1:-origin}"

SEMVER_REGEX="^refs/tags/v?[0-9]+\.[0-9]+\.[0-9]+$"

while read -r _local_ref local_sha remote_ref remote_sha; do
	# Check if pushed ref is a SemVer release tag
	if [[ "$remote_ref" =~ $SEMVER_REGEX ]]; then
		tag_name="${remote_ref#refs/tags/}"

		# Check if tag already exists on remote
		if [ -n "$remote_sha" ] && [ "$remote_sha" != "0000000000000000000000000000000000000000" ]; then
			if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
				echo "❌ ERROR: Deleting release tag '$tag_name' on remote '$REMOTE' is prohibited." >&2
				exit 1
			elif [ "$local_sha" != "$remote_sha" ]; then
				echo "❌ ERROR: Release tag '$tag_name' already exists on remote '$REMOTE' ($remote_sha)." >&2
				echo "   SemVer release tags are immutable and cannot be moved or overwritten." >&2
				echo "   Please bump to the next patch or minor version instead." >&2
				exit 1
			fi
		fi
	fi
done

exit 0
