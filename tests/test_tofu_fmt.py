"""Unit tests for OpenTofu format hook (tofu-fmt.sh)."""

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK_SCRIPT = REPO_ROOT / "hooks" / "tofu-fmt.sh"


def test_hook_script_exists_and_executable():
    assert HOOK_SCRIPT.is_file(), "hooks/tofu-fmt.sh must exist"
    assert os.access(HOOK_SCRIPT, os.X_OK), "hooks/tofu-fmt.sh must be executable"


def test_tofu_fmt_executes_cleanly_on_empty_args():
    result = subprocess.run([str(HOOK_SCRIPT)], capture_output=True, text=True)
    assert result.returncode == 0


def test_tofu_fmt_formats_tf_file(tmp_path):
    unformatted_tf = tmp_path / "main.tf"
    unformatted_tf.write_text('variable   "foo"   {\n  type = string\n}\n')

    result = subprocess.run([str(HOOK_SCRIPT), str(unformatted_tf)], capture_output=True, text=True)
    assert result.returncode == 0
    formatted_content = unformatted_tf.read_text()
    assert 'variable "foo" {' in formatted_content
