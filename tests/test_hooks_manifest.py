"""Unit tests for .pre-commit-hooks.yaml manifest validity."""

from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_FILE = REPO_ROOT / ".pre-commit-hooks.yaml"


def test_manifest_exists():
    assert MANIFEST_FILE.is_file(), ".pre-commit-hooks.yaml must exist"


def test_all_declared_hooks_valid():
    with open(MANIFEST_FILE, encoding="utf-8") as f:
        hooks = yaml.safe_load(f)

    assert isinstance(hooks, list) and len(hooks) > 0, "Manifest must declare a list of hooks"

    for hook in hooks:
        hook_id = hook.get("id")
        assert hook_id, f"Hook missing id: {hook}"
        assert hook.get("name"), f"Hook {hook_id} missing name"
        assert hook.get("description"), f"Hook {hook_id} missing description"
        assert hook.get("entry"), f"Hook {hook_id} missing entry"

        entry_script = REPO_ROOT / hook["entry"]
        assert entry_script.is_file(), (
            f"Hook script {hook['entry']} for '{hook_id}' does not exist on disk"
        )
        import os

        assert os.access(entry_script, os.X_OK), (
            f"Hook script {hook['entry']} for '{hook_id}' must be executable"
        )
