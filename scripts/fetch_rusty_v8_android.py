#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
import tomllib
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPOSITORY = "DioNanos/codex-termux"
DEFAULT_TARGET = "aarch64-linux-android"
MANIFEST_PATH = ROOT / "third_party" / "v8" / "android-artifacts.toml"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def resolved_v8_crate_version() -> str:
    cargo_lock = tomllib.loads((ROOT / "codex-rs" / "Cargo.lock").read_text())
    versions = sorted(
        {
            package["version"]
            for package in cargo_lock["package"]
            if package["name"] == "v8"
        }
    )
    if len(versions) != 1:
        raise SystemExit(f"expected exactly one resolved v8 version, found: {versions}")
    return versions[0]


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f"{destination.name}.part")
    temporary.unlink(missing_ok=True)
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "pygojrc-codex-termux-release-builder"},
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response, temporary.open(
            "wb"
        ) as output:
            shutil.copyfileobj(response, output)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch checksum-pinned rusty_v8 Android artifacts for Cargo builds."
    )
    parser.add_argument(
        "--repository",
        default=DEFAULT_REPOSITORY,
        help=f"Fallback GitHub repository (default: {DEFAULT_REPOSITORY})",
    )
    parser.add_argument(
        "--target",
        default=DEFAULT_TARGET,
        help=f"Rust target triple to fetch (default: {DEFAULT_TARGET})",
    )
    parser.add_argument(
        "--release-tag",
        help="Optional release tag override. The manifest entry and hashes remain mandatory.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(ROOT / ".artifacts" / "rusty_v8"),
        help="Directory where the archive and binding will be stored.",
    )
    return parser.parse_args()


def load_manifest() -> dict[str, object]:
    if not MANIFEST_PATH.is_file():
        raise SystemExit(f"missing Android V8 artifact manifest: {MANIFEST_PATH}")
    return tomllib.loads(MANIFEST_PATH.read_text())


def manifest_entry(version: str, target: str) -> dict[str, str] | None:
    manifest = load_manifest()
    versions = manifest.get("versions")
    if not isinstance(versions, dict):
        return None
    version_entry = versions.get(version)
    if not isinstance(version_entry, dict):
        return None
    targets = version_entry.get("targets")
    if not isinstance(targets, dict):
        return None
    target_entry = targets.get(target)
    if not isinstance(target_entry, dict):
        return None
    return {key: value for key, value in target_entry.items() if isinstance(value, str)}


def required_manifest_value(entry: dict[str, str], key: str) -> str:
    value = entry.get(key, "").strip()
    if not value:
        raise SystemExit(f"manifest entry is missing required field: {key}")
    return value


def main() -> int:
    args = parse_args()
    version = resolved_v8_crate_version()
    manifest = manifest_entry(version, args.target)
    if manifest is None:
        raise SystemExit(
            "no checksum-pinned rusty_v8 Android artifact entry for "
            f"v8={version}, target={args.target}"
        )

    manifest_release_tag = required_manifest_value(manifest, "release_tag")
    release_tag = args.release_tag or manifest_release_tag
    repository = manifest.get("repository", args.repository).strip()
    if not REPOSITORY_RE.fullmatch(repository):
        raise SystemExit(f"invalid GitHub repository slug in manifest: {repository!r}")

    expected_archive_sha = required_manifest_value(manifest, "archive_sha256")
    expected_binding_sha = required_manifest_value(manifest, "binding_sha256")
    if not SHA256_RE.fullmatch(expected_archive_sha):
        raise SystemExit("manifest archive_sha256 must be 64 lowercase hexadecimal characters")
    if not SHA256_RE.fullmatch(expected_binding_sha):
        raise SystemExit("manifest binding_sha256 must be 64 lowercase hexadecimal characters")

    output_dir = Path(args.output_dir).resolve()
    archive_name = f"librusty_v8_release_{args.target}.a.gz"
    binding_name = f"src_binding_release_{args.target}.rs"

    base_url = f"https://github.com/{repository}/releases/download/{release_tag}"
    archive_url = f"{base_url}/{archive_name}"
    binding_url = f"{base_url}/{binding_name}"

    archive_path = output_dir / release_tag / archive_name
    binding_path = output_dir / release_tag / binding_name

    try:
        download(archive_url, archive_path)
        download(binding_url, binding_path)
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            "failed to download checksum-pinned rusty_v8 Android artifacts; "
            f"missing asset or tag: {exc.url} ({exc.code})"
        ) from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"failed to download rusty_v8 Android artifacts: {exc}") from exc

    actual_archive_sha = sha256(archive_path)
    actual_binding_sha = sha256(binding_path)
    if actual_archive_sha != expected_archive_sha:
        archive_path.unlink(missing_ok=True)
        raise SystemExit(
            f"archive checksum mismatch for {archive_path}; "
            f"expected {expected_archive_sha}, got {actual_archive_sha}"
        )
    if actual_binding_sha != expected_binding_sha:
        binding_path.unlink(missing_ok=True)
        raise SystemExit(
            f"binding checksum mismatch for {binding_path}; "
            f"expected {expected_binding_sha}, got {actual_binding_sha}"
        )

    print(f"resolved v8 crate version: {version}")
    print(f"release tag: {release_tag}")
    print(f"repository: {repository}")
    print(f"archive: {archive_path}")
    print(f"archive sha256: {actual_archive_sha}")
    print(f"binding: {binding_path}")
    print(f"binding sha256: {actual_binding_sha}")
    print()
    print(f'export RUSTY_V8_ARCHIVE="{archive_path}"')
    print(f'export RUSTY_V8_SRC_BINDING_PATH="{binding_path}"')
    return 0


if __name__ == "__main__":
    sys.exit(main())
