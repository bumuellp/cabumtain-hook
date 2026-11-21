import os
import shutil
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
JS_LINT_SCRIPT = REPO_ROOT / "hooks" / "js-lint.sh"


def _minimal_env(extra_bin: Path, home_dir: Path) -> dict[str, str]:
    return {
        "PATH": f"{extra_bin}:/usr/bin:/bin",
        "HOME": str(home_dir),
    }


def test_js_lint_script_exists_and_executable():
    assert JS_LINT_SCRIPT.is_file(), f"{JS_LINT_SCRIPT} must exist"
    if not os.access(JS_LINT_SCRIPT, os.X_OK):
        JS_LINT_SCRIPT.chmod(0o755)
    assert os.access(JS_LINT_SCRIPT, os.X_OK), f"{JS_LINT_SCRIPT} must be executable"


def test_js_lint_ignores_non_js_files(tmp_path):
    readme = tmp_path / "README.md"
    readme.write_text("# Notes\n", encoding="utf-8")
    result = subprocess.run(
        [str(JS_LINT_SCRIPT), str(readme)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
    assert result.stdout == ""


def test_js_lint_prefers_local_bin_and_enables_type_aware(tmp_path):
    proj = tmp_path / "frontend"
    local_bin = proj / "node_modules" / ".bin"
    local_bin.mkdir(parents=True)
    log_file = tmp_path / "oxlint.log"

    oxlint_bin = local_bin / "oxlint"
    oxlint_bin.write_text(
        f'#!/usr/bin/env bash\npwd >> "{log_file}"\nprintf "%s\\n" "$*" >> "{log_file}"\nexit 0\n',
        encoding="utf-8",
    )
    oxlint_bin.chmod(0o755)

    tsgolint_bin = local_bin / "tsgolint"
    tsgolint_bin.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
    tsgolint_bin.chmod(0o755)

    (proj / "package.json").write_text('{"name":"app"}\n', encoding="utf-8")
    src = proj / "src"
    src.mkdir()
    ts_file = src / "my file.ts"
    ts_file.write_text("export const x = 1;\n", encoding="utf-8")

    result = subprocess.run(
        ["bash", str(JS_LINT_SCRIPT), "frontend/src/my file.ts"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=_minimal_env(tmp_path / "empty-bin", tmp_path),
    )
    assert result.returncode == 0, result.stderr
    lines = log_file.read_text(encoding="utf-8").splitlines()
    assert lines[0] == str(proj)
    assert lines[1] == "--type-aware src/my file.ts"


def test_js_lint_falls_back_to_path_oxlint_without_type_aware(tmp_path):
    proj = tmp_path / "web"
    (proj / "src").mkdir(parents=True)
    (proj / ".oxlintrc.json").write_text("{}\n", encoding="utf-8")
    ts_file = proj / "src" / "app.ts"
    ts_file.write_text("export const ok = true;\n", encoding="utf-8")

    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    log_file = tmp_path / "path_oxlint.log"
    mock_oxlint = mock_bin / "oxlint"
    mock_oxlint.write_text(
        f'#!/usr/bin/env bash\necho "$*" >> "{log_file}"\nexit 0\n',
        encoding="utf-8",
    )
    mock_oxlint.chmod(0o755)

    result = subprocess.run(
        ["bash", str(JS_LINT_SCRIPT), "web/src/app.ts"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=_minimal_env(mock_bin, tmp_path),
    )
    assert result.returncode == 0, result.stderr
    assert log_file.read_text(encoding="utf-8").splitlines() == ["src/app.ts"]


def test_js_lint_propagates_oxlint_failure(tmp_path):
    (tmp_path / "bad.ts").write_text("const x = 1;\n", encoding="utf-8")
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    mock_oxlint = mock_bin / "oxlint"
    mock_oxlint.write_text('#!/usr/bin/env bash\necho "lint error" >&2\nexit 1\n', encoding="utf-8")
    mock_oxlint.chmod(0o755)

    result = subprocess.run(
        ["bash", str(JS_LINT_SCRIPT), "bad.ts"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=_minimal_env(mock_bin, tmp_path),
    )
    assert result.returncode == 1
    assert "lint error" in result.stderr


def test_js_lint_missing_tool_fails_hard(tmp_path):
    (tmp_path / "app.ts").write_text("export const a = 1;\n", encoding="utf-8")
    mock_bin = tmp_path / "bin"
    mock_bin.mkdir()
    for tool in ("bash", "dirname", "basename", "printf"):
        p = shutil.which(tool)
        if p:
            os.symlink(p, mock_bin / tool)

    result = subprocess.run(
        ["bash", str(JS_LINT_SCRIPT), "app.ts"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env=_minimal_env(mock_bin, tmp_path),
    )
    assert result.returncode == 1
    assert "oxlint" in result.stderr.lower()
