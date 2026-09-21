#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/utils.sh"

k8s_files=()
while IFS= read -r -d '' file_path; do
	[ -z "$file_path" ] && continue
	case "$file_path" in
	k8s/*)
		case "$file_path" in
		*.yaml | *.yml)
			[ -f "$file_path" ] && k8s_files+=("$file_path")
			;;
		esac
		;;
	esac
done < <(get_target_files "$@")

# Skip if no k8s files were changed or staged
[ "${#k8s_files[@]}" -eq 0 ] && exit 0

KUBECONFORM_CMD="$(require_tool kubeconform 'kubeconform is required for Kubernetes manifest schema validation.')"
KUBESCORE_CMD="$(require_tool kube-score 'kube-score is required for Kubernetes best-practice audits.')"
KUSTOMIZE_CMD="$(find_tool kustomize || true)"

K8S_VER="1.36.4"
K8S_MIN="v1.36"
if [ -f ".k8s-version" ]; then
	# shellcheck disable=SC1091
	. ./.k8s-version
	K8S_VER="${KUBERNETES_VERSION:-1.36.4}"
	K8S_MIN="${KUBERNETES_MINOR:-v1.36}"
fi

SCHEMA_CRD="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
CACHE_DIR=".cache/kubeconform"
mkdir -p "$CACHE_DIR"

# Validate the FULL rendered production overlay (The Whole Picture)
if [ -n "$KUSTOMIZE_CMD" ] && [ -d "k8s/overlays/production" ]; then
	echo "Running Kustomize render + Kubeconform schema validation ($K8S_VER)..."
	"$KUSTOMIZE_CMD" build k8s/overlays/production | "$KUBECONFORM_CMD" -summary -cache "$CACHE_DIR" -kubernetes-version "$K8S_VER" -schema-location default -schema-location "$SCHEMA_CRD" -ignore-missing-schemas -

	echo "Running Kube-score best-practice audit on rendered production manifests ($K8S_MIN)..."
	"$KUSTOMIZE_CMD" build k8s/overlays/production | "$KUBESCORE_CMD" score --kubernetes-version "$K8S_MIN" -
elif [ "${#k8s_files[@]}" -gt 0 ]; then
	echo "Running Kubeconform schema validation on staged files ($K8S_VER)..."
	"$KUBECONFORM_CMD" -summary -cache "$CACHE_DIR" -kubernetes-version "$K8S_VER" -schema-location default -schema-location "$SCHEMA_CRD" -ignore-missing-schemas "${k8s_files[@]}"

	echo "Running Kube-score best-practice audit on staged manifests ($K8S_MIN)..."
	"$KUBESCORE_CMD" score --kubernetes-version "$K8S_MIN" "${k8s_files[@]}"
fi
