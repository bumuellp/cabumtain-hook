"""Unit tests for Trivy scanning hook (hooks/trivy.sh)."""

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TRIVY_SCRIPT = REPO_ROOT / "hooks" / "trivy.sh"


def test_trivy_script_exists_and_executable():
    assert TRIVY_SCRIPT.is_file(), f"{TRIVY_SCRIPT} must exist"
    assert os.access(TRIVY_SCRIPT, os.X_OK), f"{TRIVY_SCRIPT} must be executable"


def test_trivy_unknown_mode():
    result = subprocess.run(
        [str(TRIVY_SCRIPT), "--mode=unknown_invalid_mode"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1
    assert "Unknown scan mode 'unknown_invalid_mode'" in result.stderr


def test_trivy_missing_binary_fails_hard(tmp_path):
    # Execute with an empty PATH to guarantee trivy is not found
    env = os.environ.copy()
    env["PATH"] = str(tmp_path)
    env["HOME"] = str(tmp_path)

    result = subprocess.run(
        [str(TRIVY_SCRIPT), "--mode=config"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 1
    assert "ERROR: trivy binary is not installed" in result.stderr


def test_trivy_config_execution():
    result = subprocess.run(
        [str(TRIVY_SCRIPT), "--mode=config"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    # If trivy is installed, it runs config scan; either 0 or 1 based on findings
    if result.returncode != 0:
        assert "trivy" in result.stderr.lower() or "trivy" in result.stdout.lower()
    else:
        assert "Trivy configuration" in result.stdout


def test_trivy_fs_execution():
    result = subprocess.run(
        [str(TRIVY_SCRIPT), "--mode=fs"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        assert "trivy" in result.stderr.lower() or "trivy" in result.stdout.lower()
    else:
        assert "Trivy filesystem" in result.stdout
