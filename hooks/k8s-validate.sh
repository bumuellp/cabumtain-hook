#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
	files="$*"
else
	files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
fi

k8s_files=""
for file_path in $files; do
	case "$file_path" in
	k8s/*)
		case "$file_path" in
		*.yaml | *.yml)
			[ -f "$file_path" ] && k8s_files="$k8s_files $file_path"
			;;
		esac
		;;
	esac
done

# Skip if no k8s files were changed or staged
[ -z "$k8s_files" ] && exit 0

KUBECONFORM_CMD="kubeconform"
if ! command -v kubeconform >/dev/null 2>&1; then
	if [ -x "$HOME/.local/bin/kubeconform" ]; then
		KUBECONFORM_CMD="$HOME/.local/bin/kubeconform"
	else
		echo "ERROR: kubeconform is required for Kubernetes manifest schema validation." >&2
		exit 1
	fi
fi

KUBESCORE_CMD="kube-score"
if ! command -v kube-score >/dev/null 2>&1; then
	if [ -x "$HOME/.local/bin/kube-score" ]; then
		KUBESCORE_CMD="$HOME/.local/bin/kube-score"
	else
		echo "ERROR: kube-score is required for Kubernetes best-practice audits." >&2
		exit 1
	fi
fi

KUSTOMIZE_CMD=""
if command -v kustomize >/dev/null 2>&1; then
	KUSTOMIZE_CMD="kustomize"
elif [ -x "$HOME/.local/bin/kustomize" ]; then
	KUSTOMIZE_CMD="$HOME/.local/bin/kustomize"
fi

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
elif [ -n "$k8s_files" ]; then
	echo "Running Kubeconform schema validation on staged files ($K8S_VER)..."
	# shellcheck disable=SC2086
	"$KUBECONFORM_CMD" -summary -cache "$CACHE_DIR" -kubernetes-version "$K8S_VER" -schema-location default -schema-location "$SCHEMA_CRD" -ignore-missing-schemas $k8s_files

	echo "Running Kube-score best-practice audit on staged manifests ($K8S_MIN)..."
	# shellcheck disable=SC2086
	"$KUBESCORE_CMD" score --kubernetes-version "$K8S_MIN" $k8s_files
fi
