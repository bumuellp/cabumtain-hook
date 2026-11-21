"""Unit tests for AI Slop Scanner hook (aislop.sh)."""

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK_SCRIPT = REPO_ROOT / "hooks" / "aislop.sh"


def test_hook_script_exists_and_executable():
    assert HOOK_SCRIPT.is_file(), "hooks/aislop.sh must exist"
    assert os.access(HOOK_SCRIPT, os.X_OK), "hooks/aislop.sh must be executable"


def test_aislop_runs_with_mock_binary(tmp_path):
    mock_bin = tmp_path / "aislop"
    args_file = tmp_path / "args.txt"
    mock_bin.write_text(
        f'#!/usr/bin/env bash\nprintf "%s\\n" "$*" > "{args_file}"\n',
        encoding="utf-8",
    )
    mock_bin.chmod(0o755)

    env = os.environ.copy()
    env["PATH"] = f"{tmp_path}:{env.get('PATH', '')}"

    result = subprocess.run([str(HOOK_SCRIPT)], env=env, capture_output=True, text=True)
    assert result.returncode == 0
    assert args_file.read_text(encoding="utf-8").strip() == "scan --staged"
