"""Update flow for bun2nix packages built from GitHub sources."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.bun import clone_and_generate_bun_nix
from updater.hashes_file import load_hashes, save_hashes
from updater.nix import nix_prefetch_url
from updater.version import fetch_github_latest_release, should_update

if TYPE_CHECKING:
    from pathlib import Path


def update_bun_github(
    pkg_dir: Path,
    owner: str,
    repo: str,
    *,
    ref_prefix: str = "v",
) -> None:
    """Update a bun2nix package built from a GitHub release source tarball.

    Bumps version/hash in hashes.json and regenerates bun.nix from the
    upstream bun.lock.
    """
    flake_root = pkg_dir.parent.parent
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]
    latest = fetch_github_latest_release(owner, repo)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print("Calculating source hash...")
    url = (
        f"https://github.com/{owner}/{repo}/archive/refs/tags/"
        f"{ref_prefix}{latest}.tar.gz"
    )
    src_hash = nix_prefetch_url(url, unpack=True)

    save_hashes(hashes_file, {"version": latest, "hash": src_hash})

    clone_and_generate_bun_nix(
        owner,
        repo,
        latest,
        pkg_dir / "bun.nix",
        flake_root,
        ref_prefix=ref_prefix,
    )

    print(f"Updated to {latest}")
