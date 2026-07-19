"""Update flow for packages built from a GitHub release source tarball."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.deps import update_dependency_hash
from updater.hash import DUMMY_SHA256_HASH, calculate_url_hash
from updater.hashes_file import load_hashes, save_hashes
from updater.version import fetch_github_latest_release, should_update

if TYPE_CHECKING:
    from pathlib import Path


def update_github_source(
    pkg_dir: Path,
    owner: str,
    repo: str,
    flake_attr: str,
    dep_hash_key: str,
) -> None:
    """Update a package built from a GitHub release source tarball.

    Bumps version/hash in hashes.json and recalculates the given dependency
    hash (e.g. vendorHash for Go packages).
    """
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]
    latest = fetch_github_latest_release(owner, repo)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url = f"https://github.com/{owner}/{repo}/archive/refs/tags/v{latest}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        dep_hash_key: DUMMY_SHA256_HASH,
    }
    save_hashes(hashes_file, data)

    update_dependency_hash(flake_attr, dep_hash_key, hashes_file, data)

    print(f"Updated to {latest}")
