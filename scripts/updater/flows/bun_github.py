"""Update flow for bun2nix packages built from GitHub sources."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.bun import clone_and_generate_bun_nix
from updater.deps import update_dependency_hash
from updater.fetch import PurlFetcher
from updater.hash import DUMMY_SHA256_HASH
from updater.hashes_file import load_hashes, save_hashes
from updater.purl import Purl
from updater.version import should_update

if TYPE_CHECKING:
    from pathlib import Path


def update_bun_github(
    pkg_dir: Path,
    owner: str,
    repo: str,
    *,
    ref_prefix: str = "v",
    flake_attr: str | None = None,
    dep_hash_key: str | None = None,
) -> None:
    """Bump version/hash and regenerate bun.nix from the upstream bun.lock.

    A non-default ref_prefix becomes an x_tag_template qualifier so the
    fetcher builds the same archive URL as before. dep_hash_key names a
    further dependency hash (e.g. cargoHash of a bundled sidecar) that is
    recalculated by building flake_attr.
    """
    if dep_hash_key and not flake_attr:
        msg = "bun-github: depHashKey needs flakeAttr"
        raise ValueError(msg)
    flake_root = pkg_dir.parent.parent
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]

    fetcher = PurlFetcher.default()
    purl = Purl("github", owner, repo)
    if ref_prefix != "v":
        purl = purl.with_qualifiers(x_tag_template=f"{ref_prefix}{{v}}")
    resolved = fetcher.resolve(purl)

    print(f"Current: {current}, Latest: {resolved.version}")

    if not should_update(current, resolved.version):
        print("Already up to date")
        return

    print("Calculating source hash...")
    src_hash = fetcher.hashes(purl, resolved)["src"]

    data = {"version": resolved.version, "hash": src_hash}
    if dep_hash_key:
        data[dep_hash_key] = DUMMY_SHA256_HASH
    save_hashes(hashes_file, data)

    clone_and_generate_bun_nix(
        owner,
        repo,
        resolved.version,
        pkg_dir / "bun.nix",
        flake_root,
        ref_prefix=ref_prefix,
    )

    if dep_hash_key and flake_attr:
        update_dependency_hash(flake_attr, dep_hash_key, hashes_file, data)

    print(f"Updated to {resolved.version}")
