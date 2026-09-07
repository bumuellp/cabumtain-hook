#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
	files="$*"
else
	files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
fi

scan_needed=false
for file_path in $files; do
	case "$file_path" in
	k8s/* | homelab-podman/* | Dockerfile* | *.dockerfile)
		scan_needed=true
		break
		;;
	esac
done

[ "$scan_needed" = "false" ] && exit 0

TRIVY_CMD="trivy"
if ! command -v trivy >/dev/null 2>&1; then
	if [ -x "$HOME/.local/bin/trivy" ]; then
		TRIVY_CMD="$HOME/.local/bin/trivy"
	else
		echo "INFO: trivy not installed, skipping local trivy security scan." >&2
		echo "      Install via: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin" >&2
		exit 0
	fi
fi

echo "Running Trivy configuration & security scan..."
"$TRIVY_CMD" config --exit-code 1 --severity HIGH,CRITICAL .
