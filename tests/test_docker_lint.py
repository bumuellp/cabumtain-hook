import os
import shutil
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCKER_LINT_SCRIPT = REPO_ROOT / "hooks" / "docker-lint.sh"


def test_docker_lint_script_exists_and_executable():
    assert DOCKER_LINT_SCRIPT.is_file(), f"{DOCKER_LINT_SCRIPT} must exist"
    assert os.access(DOCKER_LINT_SCRIPT, os.X_OK), f"{DOCKER_LINT_SCRIPT} must be executable"


def test_docker_lint_no_dockerfiles(tmp_path):
    # Running with no dockerfiles should exit cleanly with 0
    test_file = tmp_path / "README.md"
    test_file.write_text("# Test\n")
    result = subprocess.run(
        [str(DOCKER_LINT_SCRIPT), str(test_file)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0


def test_docker_lint_valid_dockerfile(tmp_path):
    df = tmp_path / "Dockerfile"
    df.write_text('FROM debian:bookworm-slim\nUSER 1000:1000\nCMD ["echo", "hello"]\n')
    result = subprocess.run(
        [str(DOCKER_LINT_SCRIPT), str(df)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "Hadolint" in result.stdout


def test_docker_lint_missing_tool_fails_hard(tmp_path):
    # Ensure environment without hadolint, docker, or podman fails with error
    df = tmp_path / "Dockerfile"
    df.write_text("FROM debian:bookworm-slim\n")

    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    for tool in ["bash", "grep", "head", "git", "pwd"]:
        p = shutil.which(tool)
        if p:
            os.symlink(p, mock_bin / tool)

    env = os.environ.copy()
    env["PATH"] = str(mock_bin)
    env["HOME"] = str(tmp_path)

    result = subprocess.run(
        [str(DOCKER_LINT_SCRIPT), str(df)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 1
    assert "hadolint" in result.stderr.lower()
