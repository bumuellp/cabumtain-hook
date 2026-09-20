#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Unified Trivy Scanner Hook (IaC Config & Filesystem / License Scanning)
# ==============================================================================

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
# shellcheck source=hooks/utils.sh
. "$SCRIPT_DIR/utils.sh"

MODE="config"
EXTRA_ARGS=""

# Parse flags
while [ "$#" -gt 0 ]; do
	case "$1" in
	--mode=*)
		MODE="${1#*=}"
		shift
		;;
	-m | --mode)
		MODE="$2"
		shift 2
		;;
	--)
		shift
		break
		;;
	*)
		# Pass other flags through to Trivy
		if [ -z "$EXTRA_ARGS" ]; then
			EXTRA_ARGS="$1"
		else
			EXTRA_ARGS="$EXTRA_ARGS $1"
		fi
		shift
		;;
	esac
done

TRIVY_INSTALL_MSG=$(printf "trivy binary is not installed or not found in PATH.\n       Install via: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin")
TRIVY_CMD="$(require_tool trivy "$TRIVY_INSTALL_MSG")"

# Execute corresponding scan mode
case "$MODE" in
config)
	echo "Running Trivy configuration & IaC security scan..."
	if [ -f "trivy.yaml" ] || [ -f ".trivy.yaml" ]; then
		# Respect repo's trivy.yaml, ensure failures block commit
		# shellcheck disable=SC2086
		"$TRIVY_CMD" config --exit-code 1 $EXTRA_ARGS .
	else
		# shellcheck disable=SC2086
		"$TRIVY_CMD" config --exit-code 1 --severity HIGH,CRITICAL $EXTRA_ARGS .
	fi
	;;

fs | filesystem)
	echo "Running Trivy filesystem, vulnerability & license scan..."
	if [ -f "trivy.yaml" ] || [ -f ".trivy.yaml" ]; then
		# Respect repo's trivy.yaml, ensure failures block commit
		# shellcheck disable=SC2086
		"$TRIVY_CMD" fs --exit-code 1 $EXTRA_ARGS .
	else
		# shellcheck disable=SC2086
		"$TRIVY_CMD" fs --scanners vuln,secret,license --severity HIGH,CRITICAL --exit-code 1 $EXTRA_ARGS .
	fi
	;;

*)
	echo "ERROR: Unknown scan mode '$MODE'. Supported modes: config, fs" >&2
	exit 1
	;;
esac
