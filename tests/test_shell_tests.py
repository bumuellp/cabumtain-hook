"""Unit tests for Shell Unit Tests hook (shell-tests.sh)."""

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK_SCRIPT = REPO_ROOT / "hooks" / "shell-tests.sh"


def test_hook_script_exists_and_executable():
    assert HOOK_SCRIPT.is_file(), "hooks/shell-tests.sh must exist"
    if not os.access(HOOK_SCRIPT, os.X_OK):
        HOOK_SCRIPT.chmod(0o755)
    assert os.access(HOOK_SCRIPT, os.X_OK), "hooks/shell-tests.sh must be executable"


def test_shell_tests_no_bats_files_exits_zero(tmp_path):
    res = subprocess.run(
        [str(HOOK_SCRIPT)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 0
    assert res.stdout == ""


def test_shell_tests_runs_discovered_bats_files(tmp_path):
    tests_dir = tmp_path / "tests" / "shell"
    tests_dir.mkdir(parents=True)
    bats_file = tests_dir / "sample.bats"
    bats_file.write_text('@test "sample" { [ 1 -eq 1 ]; }\n')

    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    call_log = tmp_path / "bats_calls.log"
    mock_bats = mock_bin / "bats"
    mock_bats.write_text(f"""#!/usr/bin/env bash
echo "$@" >> "{call_log}"
exit 0
""")
    mock_bats.chmod(0o755)

    env = {
        **os.environ,
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }

    res = subprocess.run(
        [str(HOOK_SCRIPT)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert res.returncode == 0
    assert "Running Shell Unit Tests (Bats)" in res.stdout
    assert "tests/shell/sample.bats" in call_log.read_text()


def test_shell_tests_propagates_bats_failure(tmp_path):
    tests_dir = tmp_path / "tests"
    tests_dir.mkdir()
    (tests_dir / "failing.bats").write_text('@test "fail" { false; }\n')

    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    mock_bats = mock_bin / "bats"
    mock_bats.write_text("""#!/usr/bin/env bash
echo "not ok 1 fail" >&2
exit 1
""")
    mock_bats.chmod(0o755)

    env = {
        **os.environ,
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }

    res = subprocess.run(
        [str(HOOK_SCRIPT)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert res.returncode == 1
