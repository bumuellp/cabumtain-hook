# cabumtain-hook

Modular, shared Git and `pre-commit` hooks for linting, secrets scanning, security audits, formatting, and commit message standardization across homelab and application repositories.

---

## 📦 Available Hooks

| Hook ID | Description | Default Trigger / Files | Tools Required |
| :--- | :--- | :--- | :--- |
| `commit-msg` | Validates Conventional Commit header (`feat`, `fix`, `docs`, etc. max 72 chars) | `stages: [commit-msg]` | POSIX shell |
| `secret-scan` | TruffleHog credential & secrets scanner (offline local / verified CI) | Staged commits | `trufflehog` |
| `pre-commit-all` | Sequential runner executing all modular checks | Staged commits | POSIX shell |
| `shell-lint` | Autoformats with `shfmt` and lints with `shellcheck` | `types: [shell]` | `shfmt`, `shellcheck` |
| `ansible-lint` | Validates playbook syntax and runs Ansible static analysis | `ansible/**/*.ya?ml` | `ansible-playbook`, `ansible-lint` |
| `yaml-xml-lint` | Lints YAML with `yamllint` (ignores `.enc.yml`) and parses XML | `*.ya?ml`, `*.xml` | `yamllint`, `xmllint` / `python3` |
| `python-tests` | Runs unit tests if `tests/` directory exists | `*.py` | `pytest` / `unittest` |
| `k8s-validate` | Schema validation and best-practice audit | `k8s/**/*.ya?ml` | `kustomize`, `kubeconform`, `kube-score` |
| `trivy-security` | Trivy config and vulnerability scan on container definitions | `k8s/`, `Dockerfile`, Podman | `trivy` |

---

## 🚀 Integration in Your Repositories

### Recommended `.pre-commit-config.yaml` Setup

```yaml
repos:
  # Standard auto-fixers for whitespace, EOF, and line endings
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: mixed-line-ending
        args: [--fix=lf]

  # Cabumtain shared hooks
  - repo: https://github.com/bumuellp/cabumtain-hook
    rev: main  # or tag e.g. v1.0.0
    hooks:
      - id: commit-msg
      - id: secret-scan
      - id: shell-lint
      - id: yaml-xml-lint
      - id: trivy-security
      # Optional repo-specific hooks:
      # - id: ansible-lint
      # - id: k8s-validate
      # - id: python-tests
```

Install the hooks in your repo:
```bash
pre-commit install --hook-type pre-commit --hook-type commit-msg
```
