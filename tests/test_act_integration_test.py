"""Unit tests for act-integration-test.sh hook failure modes and guards."""

import os
import subprocess
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "act-integration-test.sh"


def test_act_integration_test_hook_exists():
    assert HOOK_PATH.is_file(), f"Hook script not found: {HOOK_PATH}"
    assert os.access(HOOK_PATH, os.X_OK), "Hook script must be executable"


def test_act_skips_in_github_actions_ci():
    """Hook must immediately exit 0 when executing inside GitHub Actions CI."""
    env = {"GITHUB_ACTIONS": "true", "PATH": os.environ.get("PATH", "")}
    res = subprocess.run(
        ["bash", str(HOOK_PATH)], capture_output=True, text=True, check=False, env=env
    )
    assert res.returncode == 0
    assert "Skipping local act runner" in res.stdout


def test_act_fails_when_act_binary_missing(tmp_path):
    """Hook must fail with exit 1 and install instructions when act is not found."""
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()

    # PATH with standard utils (bash) but without act or gh
    env = {
        "GITHUB_ACTIONS": "false",
        "PATH": f"{mock_bin}:/bin:/usr/bin",
    }
    res = subprocess.run(
        ["bash", str(HOOK_PATH)], capture_output=True, text=True, check=False, env=env, cwd=tmp_path
    )
    assert res.returncode == 1
    assert "act' is required for pre-push integration testing" in res.stderr


def test_act_fails_when_docker_daemon_unavailable(tmp_path):
    """Hook must fail when docker daemon is not responding."""
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()

    # Mock act
    mock_act = mock_bin / "act"
    mock_act.write_text("#!/bin/sh\nexit 0\n")
    mock_act.chmod(0o755)

    # Mock docker to simulate failed daemon
    mock_docker = mock_bin / "docker"
    mock_docker.write_text("#!/bin/sh\nexit 1\n")
    mock_docker.chmod(0o755)

    env = {
        "GITHUB_ACTIONS": "false",
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }
    res = subprocess.run(
        ["bash", str(HOOK_PATH)], capture_output=True, text=True, check=False, env=env, cwd=tmp_path
    )
    assert res.returncode == 1
    assert "Docker daemon is not running or inaccessible" in res.stderr


def test_act_fails_when_no_workflow_found(tmp_path):
    """Hook must fail with exit 1 when no integration test workflow is present."""
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()

    mock_act = mock_bin / "act"
    mock_act.write_text("#!/bin/sh\nexit 0\n")
    mock_act.chmod(0o755)

    mock_docker = mock_bin / "docker"
    mock_docker.write_text("#!/bin/sh\nexit 0\n")
    mock_docker.chmod(0o755)

    # Workdir with no .github/workflows
    env = {
        "GITHUB_ACTIONS": "false",
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }
    res = subprocess.run(
        ["bash", str(HOOK_PATH)], capture_output=True, text=True, check=False, env=env, cwd=tmp_path
    )
    assert res.returncode == 1
    assert "No integration test workflow found" in res.stderr


def test_act_executes_discovered_integration_workflow(tmp_path):
    """Hook must dynamically discover and execute matching workflow."""
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    log_file = tmp_path / "act.log"

    mock_act = mock_bin / "act"
    mock_act.write_text(f"""#!/bin/sh
echo "ACT_ARGS: $@" >> "{log_file}"
exit 0
""")
    mock_act.chmod(0o755)

    mock_docker = mock_bin / "docker"
    mock_docker.write_text("#!/bin/sh\nexit 0\n")
    mock_docker.chmod(0o755)

    # Create dummy workflow
    wf_dir = tmp_path / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    (wf_dir / "integration-tests.yml").write_text("name: Test\n")

    env = {
        "GITHUB_ACTIONS": "false",
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }
    res = subprocess.run(
        ["bash", str(HOOK_PATH)], capture_output=True, text=True, check=False, env=env, cwd=tmp_path
    )
    assert res.returncode == 0
    assert "-W .github/workflows/integration-tests.yml" in log_file.read_text()


def test_act_passes_custom_arguments(tmp_path):
    """Custom arguments passed via CLI/args must be forwarded directly to act."""
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    log_file = tmp_path / "act.log"

    mock_act = mock_bin / "act"
    mock_act.write_text(f"""#!/bin/sh
echo "ACT_ARGS: $@" >> "{log_file}"
exit 0
""")
    mock_act.chmod(0o755)

    mock_docker = mock_bin / "docker"
    mock_docker.write_text("#!/bin/sh\nexit 0\n")
    mock_docker.chmod(0o755)

    env = {
        "GITHUB_ACTIONS": "false",
        "PATH": f"{mock_bin}:{os.environ.get('PATH', '')}",
    }
    custom_args = ["-W", ".github/workflows/custom.yml", "-j", "my-job"]
    res = subprocess.run(
        ["bash", str(HOOK_PATH)] + custom_args,
        capture_output=True,
        text=True,
        check=False,
        env=env,
        cwd=tmp_path,
    )
    assert res.returncode == 0
    assert "ACT_ARGS: -W .github/workflows/custom.yml -j my-job" in log_file.read_text()
