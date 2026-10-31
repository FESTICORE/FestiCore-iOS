#!/usr/bin/env python3
"""Safety checks for the CI-only DerivedData cleanup script."""

import os
from pathlib import Path
import subprocess
import tempfile
from typing import Mapping, Optional


SCRIPT = Path(__file__).with_name("clean-ci-derived-data.sh")


def run(
    home: Path,
    selected: Optional[Path],
    directory: str,
    run_id: Optional[str] = "12345",
    attempt: Optional[str] = "2",
    extra_env: Optional[Mapping[str, str]] = None,
) -> subprocess.CompletedProcess:
    environment = os.environ.copy()
    environment["HOME"] = str(home)
    environment.update(extra_env or {})
    for key, value in (("GITHUB_RUN_ID", run_id), ("GITHUB_RUN_ATTEMPT", attempt)):
        if value is None:
            environment.pop(key, None)
        else:
            environment[key] = value
    if selected is None:
        environment.pop("CI_DERIVED_DATA", None)
    else:
        environment["CI_DERIVED_DATA"] = str(selected)
    return subprocess.run(
        ["bash", str(SCRIPT), directory],
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )


with tempfile.TemporaryDirectory(prefix="festicore-ci-cleanup-") as temporary:
    home = Path(temporary) / "home"
    root = home / "ci-derived-data"
    target = root / "FestiCore-preview-12345-2"
    neighbor = root / "FestiCore-pr-bundle-12345-2"
    other_run = root / "FestiCore-preview-12346-2"
    target.mkdir(parents=True)
    neighbor.mkdir()
    other_run.mkdir()
    (target / "Build").mkdir()
    (target / "CompilationCache.noindex").mkdir()
    (neighbor / "keep").touch()
    (other_run / "keep").touch()

    result = run(home, target, "FestiCore-preview")
    assert result.returncode == 0, result.stderr
    assert not target.exists()
    assert (neighbor / "keep").exists()
    assert (other_run / "keep").exists()

    fake_bin = Path(temporary) / "bin"
    fake_bin.mkdir()
    fake_rm = fake_bin / "rm"
    fake_rm.write_text(
        "#!/usr/bin/env python3\n"
        "import os, pathlib, shutil, sys\n"
        "target = pathlib.Path(sys.argv[-1])\n"
        "shutil.rmtree(target)\n"
        "spool = target / 'CompilationCache.noindex/plugin/tuist-spool'\n"
        "spool.mkdir(parents=True)\n"
        "(spool / '16611-1290.tags').write_text('12345678')\n"
        "mode = os.environ['FAKE_RM_MODE']\n"
        "if mode == 'extra':\n"
        "    (target / 'Build').mkdir()\n"
        "    (target / 'Build/keep').touch()\n"
        "if mode == 'symlink':\n"
        "    (spool / '16611-1290.tags').unlink()\n"
        "    (spool / '16611-1290.tags').symlink_to(spool)\n"
        "if mode == 'oversize':\n"
        "    (spool / '16611-1290.tags').write_bytes(b'x' * 2_000_000)\n"
        "message = 'Operation not permitted' if mode == 'permission' else 'Directory not empty'\n"
        "print(f'rm: {spool}: {message}', file=sys.stderr)\n"
        "sys.exit(1)\n"
    )
    fake_rm.chmod(0o755)
    fake_environment = {"PATH": f"{fake_bin}:{os.environ['PATH']}"}

    for mode, expected_success in (
        ("spool", True),
        ("permission", False),
        ("extra", False),
        ("symlink", False),
        ("oversize", False),
    ):
        target.mkdir()
        (target / "Build").mkdir()
        result = run(
            home, target, "FestiCore-preview",
            extra_env={**fake_environment, "FAKE_RM_MODE": mode},
        )
        assert (result.returncode == 0) == expected_success, (mode, result.stderr)
        assert (target / "CompilationCache.noindex/plugin/tuist-spool/16611-1290.tags").exists()
        if mode == "spool":
            assert "::warning::" in result.stderr
        subprocess.run(["/bin/rm", "-rf", str(target)], check=True)

    assert run(home, None, "FestiCore-preview").returncode == 0
    assert run(home, neighbor, "FestiCore-preview").returncode != 0
    assert run(home, other_run, "FestiCore-preview").returncode != 0
    assert run(home, target, "FestiCore-preview", run_id=None).returncode != 0
    assert run(home, target, "FestiCore-preview", attempt="not-a-number").returncode != 0
    assert (neighbor / "keep").exists()
    assert (other_run / "keep").exists()

    target.symlink_to(neighbor, target_is_directory=True)
    assert run(home, target, "FestiCore-preview").returncode != 0
    assert (neighbor / "keep").exists()
    target.unlink()

    assert run(home, root, "../FestiCore-preview").returncode != 0
    assert (neighbor / "keep").exists()

    actual_root = home / "actual-ci-derived-data"
    root.rename(actual_root)
    root.symlink_to(actual_root, target_is_directory=True)
    assert run(home, root / "FestiCore-pr-bundle-12345-2", "FestiCore-pr-bundle").returncode != 0
    assert (actual_root / "FestiCore-pr-bundle-12345-2" / "keep").exists()

print("CI DerivedData cleanup safety checks passed")
