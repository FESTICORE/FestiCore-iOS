#!/usr/bin/env python3
"""Import a pinned FestiCore-DesignSystem checkout without executing its files."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


EXPECTED_SOURCES = {
    "FestiCoreColor.swift",
    "FestiCoreLayout.swift",
    "FestiCoreTypography.swift",
}
SHA_PATTERN = re.compile(r"[0-9a-f]{40}\Z")
ASSET_NAME = re.compile(r"[A-Za-z][A-Za-z0-9]*\.colorset\Z")


def regular_file(path: Path) -> None:
    stat = path.lstat()
    if not path.is_file() or path.is_symlink() or stat.st_nlink != 1:
        raise ValueError(f"Expected an ordinary, unlinked file: {path}")


def walk_regular_files(root: Path) -> list[Path]:
    if not root.is_dir() or root.is_symlink():
        raise ValueError(f"Expected a directory: {root}")
    files: list[Path] = []
    for directory, directories, names in os.walk(root, followlinks=False):
        for name in directories:
            path = Path(directory) / name
            if path.is_symlink():
                raise ValueError(f"Symlink directory is forbidden: {path}")
        for name in names:
            path = Path(directory) / name
            regular_file(path)
            files.append(path.relative_to(root))
    return sorted(files)


def validate_source(source: Path, sha: str) -> tuple[list[Path], list[Path]]:
    if not SHA_PATTERN.fullmatch(sha):
        raise ValueError("Source SHA must be a full 40-character lowercase commit hash")
    actual = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual != sha:
        raise ValueError(f"Checked-out commit {actual} does not match requested {sha}")

    generated = source / "generated/ios"
    files = walk_regular_files(generated)
    swift_files = {
        path.name for path in files if path.parent == Path("Sources")
    }
    if swift_files != EXPECTED_SOURCES:
        raise ValueError(f"Unexpected generated Swift sources: {sorted(swift_files)}")
    asset_root = Path("Assets/FestiCoreColors.xcassets")
    assets = [path for path in files if path.parts[:2] == asset_root.parts]
    if not assets or asset_root / "Contents.json" not in assets:
        raise ValueError("Missing generated color asset catalog")
    for path in files:
        if path.parent == Path("Sources") and path.suffix == ".swift":
            continue
        if path == asset_root / "Contents.json":
            pass
        elif path.parent.parent == asset_root and ASSET_NAME.fullmatch(path.parent.name) and path.name == "Contents.json":
            pass
        else:
            raise ValueError(f"Unexpected generated path: {path}")
        if path.suffix == ".json":
            json.loads((generated / path).read_text(encoding="utf-8"))

    tokens = walk_regular_files(source / "tokens")
    if not tokens or any(path.suffix != ".json" for path in tokens):
        raise ValueError("Tokens must contain JSON files only")
    return files, tokens


def snapshot_digest(destination: Path, sha: str) -> str:
    files = walk_regular_files(destination)
    if (destination / ".source-sha").read_text(encoding="ascii") != sha + "\n":
        raise ValueError("Snapshot source SHA does not match")
    generated = [path for path in files if path.parts[0] in ("Sources", "Assets")]
    sources = {path.name for path in generated if path.parent == Path("Sources")}
    if sources != EXPECTED_SOURCES:
        raise ValueError("Snapshot is missing generated Swift sources")
    if Path("Assets/FestiCoreColors.xcassets/Contents.json") not in generated:
        raise ValueError("Snapshot is missing the color asset catalog")
    for path in files:
        if path == Path(".source-sha"):
            continue
        if path.parts[0] == "Tokens" and path.suffix == ".json":
            json.loads((destination / path).read_text(encoding="utf-8"))
        elif path.parent == Path("Sources") and path.suffix == ".swift":
            pass
        elif path == Path("Assets/FestiCoreColors.xcassets/Contents.json"):
            json.loads((destination / path).read_text(encoding="utf-8"))
        elif (
            path.parent.parent == Path("Assets/FestiCoreColors.xcassets")
            and ASSET_NAME.fullmatch(path.parent.name)
            and path.name == "Contents.json"
        ):
            json.loads((destination / path).read_text(encoding="utf-8"))
        else:
            raise ValueError(f"Unexpected snapshot path: {path}")
    if not any(path.parts[0] == "Tokens" for path in files):
        raise ValueError("Snapshot is missing source tokens")
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path).encode("utf-8") + b"\0")
        digest.update(hashlib.sha256((destination / path).read_bytes()).digest())
    return digest.hexdigest()


def import_tokens(source: Path, destination: Path, sha: str) -> None:
    generated_files, token_files = validate_source(source, sha)
    if destination.is_symlink():
        raise ValueError("Destination cannot be a symlink")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="design-token-import-", dir=destination.parent) as temp:
        staged = Path(temp) / "Generated"
        for relative in generated_files:
            target = staged / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / "generated/ios" / relative, target)
        for relative in token_files:
            target = staged / "Tokens" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / "tokens" / relative, target)
        (staged / ".source-sha").write_text(sha + "\n", encoding="ascii")
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(staged), destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if not SHA_PATTERN.fullmatch(args.sha):
        parser.error("--sha requires a full lowercase commit hash")
    if not args.verify_only:
        if args.source is None:
            parser.error("--source is required for import")
        import_tokens(args.source, args.destination, args.sha)
    print(snapshot_digest(args.destination, args.sha))


if __name__ == "__main__":
    main()
