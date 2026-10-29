#!/usr/bin/env python3
"""Safety checks for the CI-only DerivedData cleanup script."""

import os
from pathlib import Path
import subprocess
import tempfile
from typing import Optional


SCRIPT = Path(__file__).with_name("clean-ci-derived-data.sh")


def run(
    home: Path,
    selected: Optional[Path],
    directory: str,
    run_id: Optional[str] = "12345",
    attempt: Optional[str] = "2",
) -> subprocess.CompletedProcess:
    environment = os.environ.copy()
    environment["HOME"] = str(home)
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
