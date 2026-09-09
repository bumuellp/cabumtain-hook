"""Unit tests for commit-msg.sh Conventional Commits validator."""

import subprocess
from pathlib import Path

import pytest

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "commit-msg.sh"


def test_commit_msg_hook_exists():
    assert HOOK_PATH.is_file(), f"Hook script not found: {HOOK_PATH}"


@pytest.mark.parametrize(
    "msg",
    [
        "feat: add container smoke tests",
        "fix(ci): resolve image tagging error",
        "docs(readme): add action catalog",
        "chore: clean temporary artifacts",
        "refactor(core): simplify hook discovery",
        "test: add unit test suite",
        "perf: optimize image build caching",
        "ci(deploy): update release workflow",
        "Merge branch 'main' into feat/migration",
        'Revert "feat: experimental feature"',
        "fixup! fix(ci): resolve image tagging error",
    ],
)
def test_valid_commit_messages_pass(tmp_path, msg):
    msg_file = tmp_path / "COMMIT_EDITMSG"
    msg_file.write_text(f"{msg}\n\nExtended commit body here.\n")
    res = subprocess.run(
        ["bash", str(HOOK_PATH), str(msg_file)], capture_output=True, text=True, check=False
    )
    assert res.returncode == 0, f"Expected valid commit message '{msg}' to pass: {res.stderr}"


@pytest.mark.parametrize(
    "msg,expected_err",
    [
        ("fixed bug in deployment", "Expected Conventional Commit format"),
        ("WIP: working on stuff", "Expected Conventional Commit format"),
        ("Update README.md", "Expected Conventional Commit format"),
        ("", "Commit message rejected"),
        (
            "feat(super-long-scope-name): this commit subject is way too long and significantly exceeds seventy two characters limit",
            "Commit message header is too long",
        ),
    ],
)
def test_invalid_commit_messages_rejected(tmp_path, msg, expected_err):
    msg_file = tmp_path / "COMMIT_EDITMSG"
    msg_file.write_text(f"{msg}\n")
    res = subprocess.run(
        ["bash", str(HOOK_PATH), str(msg_file)], capture_output=True, text=True, check=False
    )
    assert res.returncode == 1
    assert expected_err in res.stderr


def test_missing_commit_msg_file_fails():
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "/path/does/not/exist"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 1
    assert "Commit message file not found" in res.stderr
