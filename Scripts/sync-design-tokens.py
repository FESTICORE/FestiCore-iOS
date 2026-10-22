#!/usr/bin/env python3
"""고정된 FestiCore-DesignSystem 커밋의 생성물과 토큰을 가져옵니다."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


SOURCE_PATHS = {
    "Colors.swift": Path("Sources/Token/Color/Colors.swift"),
    "UIColors.swift": Path("Sources/Token/Color/UIColors.swift"),
    "ShapeStyle+.swift": Path("Sources/Token/Color/ShapeStyle+.swift"),
    "FestiCoreLayout.swift": Path("Sources/Token/Layout/FestiCoreLayout.swift"),
    "FestiCoreTypography.swift": Path("Sources/Token/Typography/FestiCoreTypography.swift"),
}
TOKEN_PATH = Path("Tests/Resources/Tokens")
SHA_PATH = Path("TokenSnapshot/.source-sha")
SHA_PATTERN = re.compile(r"[0-9a-f]{40}\Z")


def generated_header(name: str) -> str:
    return (
        f"//\n//  {name}\n//  FestiCoreDesignKit\n//\n"
        "//  Created by FestiCore-DesignSystem generator.\n//\n\n"
    )


def regular_file(path: Path) -> None:
    stat = path.lstat()
    if not path.is_file() or path.is_symlink() or stat.st_nlink != 1:
        raise ValueError(f"Expected an ordinary, unlinked file: {path}")


def reject_symlink_ancestors(root: Path, relative: Path) -> None:
    current = root
    for part in relative.parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"Symlink directory is forbidden: {current}")


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
    if swift_files != SOURCE_PATHS.keys():
        raise ValueError(f"Unexpected generated Swift sources: {sorted(swift_files)}")
    for path in files:
        if path.parent != Path("Sources") or path.suffix != ".swift":
            raise ValueError(f"Unexpected generated path: {path}")
        if not (generated / path).read_text(encoding="utf-8").startswith(generated_header(path.name)):
            raise ValueError(f"Missing generated Swift header: {path}")

    tokens = walk_regular_files(source / "tokens")
    if not tokens or any(path.suffix != ".json" for path in tokens):
        raise ValueError("Tokens must contain JSON files only")
    return files, tokens


def snapshot_digest(destination: Path, sha: str) -> str:
    if destination.is_symlink():
        raise ValueError("Destination cannot be a symlink")
    reject_symlink_ancestors(destination, SHA_PATH)
    regular_file(destination / SHA_PATH)
    if (destination / SHA_PATH).read_text(encoding="ascii") != sha + "\n":
        raise ValueError("Snapshot source SHA does not match")
    for relative in SOURCE_PATHS.values():
        reject_symlink_ancestors(destination, relative)
        regular_file(destination / relative)
        if not (destination / relative).read_text(encoding="utf-8").startswith(generated_header(relative.name)):
            raise ValueError(f"Missing generated Swift header: {relative}")
    reject_symlink_ancestors(destination, TOKEN_PATH / "file.json")
    tokens = walk_regular_files(destination / TOKEN_PATH)
    if not tokens or any(path.suffix != ".json" for path in tokens):
        raise ValueError("Snapshot is missing source tokens")
    for path in tokens:
        json.loads((destination / TOKEN_PATH / path).read_text(encoding="utf-8"))
    files = sorted([*SOURCE_PATHS.values(), *(TOKEN_PATH / path for path in tokens), SHA_PATH])
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path).encode("utf-8") + b"\0")
        digest.update(hashlib.sha256((destination / path).read_bytes()).digest())
    return digest.hexdigest()


def import_tokens(source: Path, destination: Path, sha: str) -> None:
    generated_files, token_files = validate_source(source, sha)
    if destination.is_symlink():
        raise ValueError("Destination cannot be a symlink")
    destination.mkdir(parents=True, exist_ok=True)
    sources_root = destination / "Sources"
    if sources_root.exists():
        for relative in walk_regular_files(sources_root):
            if relative.name in SOURCE_PATHS and sources_root / relative != destination / SOURCE_PATHS[relative.name]:
                raise ValueError(f"Generated Swift basename is reserved: {relative}")
    for relative in [*SOURCE_PATHS.values(), TOKEN_PATH, SHA_PATH]:
        reject_symlink_ancestors(destination, relative)
        if (destination / relative).is_symlink():
            raise ValueError(f"Symlink destination is forbidden: {destination / relative}")
        target = destination / relative
        if relative in SOURCE_PATHS.values() and target.exists():
            regular_file(target)
            if not target.read_text(encoding="utf-8").startswith(generated_header(relative.name)):
                raise ValueError(f"Refusing to overwrite non-generated Swift source: {relative}")
    with tempfile.TemporaryDirectory(prefix="design-token-import-", dir=destination) as temp:
        staged = Path(temp)
        for relative in generated_files:
            target = staged / SOURCE_PATHS[relative.name]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / "generated/ios" / relative, target)
        for relative in token_files:
            target = staged / TOKEN_PATH / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / "tokens" / relative, target)
        (staged / SHA_PATH).parent.mkdir(parents=True, exist_ok=True)
        (staged / SHA_PATH).write_text(sha + "\n", encoding="ascii")
        snapshot_digest(staged, sha)
        for relative in SOURCE_PATHS.values():
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(staged / relative, target)
        if (destination / TOKEN_PATH).exists():
            shutil.rmtree(destination / TOKEN_PATH)
        shutil.copytree(staged / TOKEN_PATH, destination / TOKEN_PATH)
        (destination / SHA_PATH).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(staged / SHA_PATH, destination / SHA_PATH)


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
