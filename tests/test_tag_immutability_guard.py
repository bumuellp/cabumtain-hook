"""Unit tests for tag-immutability-guard.sh pre-push hook."""

import subprocess
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "tag-immutability-guard.sh"


def test_guard_hook_exists():
    assert HOOK_PATH.is_file(), f"Hook script not found: {HOOK_PATH}"


def test_allows_creating_new_semver_tag():
    """Pushing a new SemVer release tag that does not exist on remote must succeed."""
    # remote_sha = 0000000... indicates tag does not exist on remote yet
    stdin_data = (
        "refs/tags/v1.0.2 aaaa1111 refs/tags/v1.0.2 0000000000000000000000000000000000000000\n"
    )
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "origin"],
        input=stdin_data,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 0


def test_blocks_mutating_existing_semver_tag():
    """Pushing a different SHA to an already existing SemVer tag must fail with exit 1."""
    # remote_sha is an existing commit, local_sha is different
    stdin_data = "refs/tags/v1.0.0 bbbb2222 refs/tags/v1.0.0 aaaa1111\n"
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "origin"],
        input=stdin_data,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 1
    assert "SemVer release tags are immutable" in res.stderr
    assert "Release tag 'v1.0.0' already exists" in res.stderr


def test_blocks_deleting_existing_semver_tag():
    """Deleting an existing remote SemVer release tag must fail with exit 1."""
    # local_sha = 0000000... indicates deletion
    stdin_data = (
        "refs/tags/v1.0.0 0000000000000000000000000000000000000000 refs/tags/v1.0.0 aaaa1111\n"
    )
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "origin"],
        input=stdin_data,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 1
    assert "Deleting release tag 'v1.0.0' on remote 'origin' is prohibited" in res.stderr


def test_allows_updating_floating_major_tag():
    """Updating a floating major tag (e.g. v1, v2) must be allowed to move."""
    stdin_data = "refs/tags/v1 bbbb2222 refs/tags/v1 aaaa1111\n"
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "origin"],
        input=stdin_data,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 0


def test_allows_pushing_branch_refs():
    """Branch pushes (refs/heads/...) must be ignored by the tag guard."""
    stdin_data = "refs/heads/main bbbb2222 refs/heads/main aaaa1111\n"
    res = subprocess.run(
        ["bash", str(HOOK_PATH), "origin"],
        input=stdin_data,
        capture_output=True,
        text=True,
        check=False,
    )
    assert res.returncode == 0
