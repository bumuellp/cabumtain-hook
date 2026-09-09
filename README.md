# cabumtain-hook

Modular, production-grade Git and `pre-commit` hooks for linting, secrets scanning, security audits, formatting, commit message standardization, tag immutability protection, and local integration testing with `act`.

---

## 📦 Available Hooks Catalog

| Hook ID | Stage | Description | Required Tools |
| :--- | :--- | :--- | :--- |
| **`commit-msg`** | `commit-msg` | Validates Conventional Commit header (`feat`, `fix`, `docs`, etc. max 72 chars). | POSIX shell |
| **`secret-scan`** | `commit` | TruffleHog credential & secrets scanner (offline local / verified CI). | `trufflehog` |
| **`shell-lint`** | `commit` | Autoformats with `shfmt` and lints with `shellcheck`. | `shfmt`, `shellcheck` |
| **`yaml-xml-lint`** | `commit` | Lints YAML with `yamllint` (ignores SOPS `.enc.yml`) and parses XML. | `yamllint`, `python3` |
| **`python-tests`** | `commit` | Runs Python unit tests (`pytest` via `uv` or `.venv`) if `tests/` exists. | `uv` / `pytest` / `python3` |
| **`ansible-lint`** | `commit` | Validates Ansible playbook syntax and runs `ansible-lint`. | `ansible-lint` |
| **`k8s-validate`** | `commit` | Kubernetes manifest validation using Kustomize, Kubeconform, and Kube-score. | `kustomize`, `kubeconform`, `kube-score` |
| **`trivy-config`** | `commit` | Scans Dockerfiles, Kubernetes manifests, and IaC for security misconfigurations. | `trivy` |
| **`trivy-fs`** | `commit` | Scans filesystem dependencies, lockfiles, and code for CVEs, secrets, and licenses. | `trivy` |
| **`trivy-security`** | `commit` | Legacy alias for `trivy-config`. | `trivy` |
| **`tag-immutability-guard`** | `pre-push` | Prevents mutating or deleting existing remote SemVer release tags (`v*.*.*`). | `git`, bash |
| **`act-integration-test`** | `pre-push`, `manual` | Runs local GitHub Actions workflow integration tests with `act` before push. | `act` (or `gh act`), Docker |
| **`pre-commit-all`** | `commit` | Sequential runner executing all modular checks. | POSIX shell |

---

## 🚀 Integration in Your Repositories

### Recommended `.pre-commit-config.yaml` Setup

```yaml
---
repos:
  # Standard auto-fixers
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: mixed-line-ending
        args: [--fix=lf]

  # Cabumtain shared hooks (pin to immutable release tag)
  - repo: https://github.com/bumuellp/cabumtain-hook
    rev: v1.3.0
    hooks:
      - id: commit-msg
      - id: secret-scan
      - id: shell-lint
      - id: yaml-xml-lint
      - id: python-tests
      - id: trivy-config
      - id: trivy-fs
      # Pre-Push Guards:
      - id: tag-immutability-guard
      - id: act-integration-test
        # Optional custom workflow or job arguments:
        # args: [-W, .github/workflows/integration-tests.yml]
```

### Installation

Enable `pre-commit`, `commit-msg`, and `pre-push` stages in your local repository clone:
```bash
pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
```

---

## 🧪 Testing

This repository includes a 33-test suite executed via `pytest`, verifying:
- Git ref push parsing and SemVer tag immutability logic.
- Conventional Commit message formats, ignored prefixes, and length restrictions.
- `act` invocation, Docker daemon detection, workflow discovery, and CI recursion prevention.
- Hook manifest validity and script executable permissions.

Run tests locally:
```bash
uv run pytest tests/
```
