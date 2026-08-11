"""Update flow for packages whose upstream ships a JSON manifest of binaries."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.hash import hex_to_sri
from updater.hashes_file import load_hashes, save_hashes
from updater.http import fetch_json
from updater.version import should_update

if TYPE_CHECKING:
    from pathlib import Path


def update_manifest_binaries(
    pkg_dir: Path,
    *,
    manifest_url: str,
    platform_map: dict[tuple[str, str], str],
) -> None:
    """Update a package from a manifest listing per-platform urls and sha256.

    The manifest must contain ``latest`` and a ``files`` list with ``os``,
    ``arch``, ``url`` and ``sha256`` (hex) entries. ``platform_map`` maps
    ``(os, arch)`` pairs to Nix platform names. Upstream has changed file
    naming before, so the exact URL is recorded rather than reconstructed.
    """
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]

    manifest = fetch_json(manifest_url)
    if not isinstance(manifest, dict):
        msg = "Manifest is not a JSON object"
        raise TypeError(msg)
    latest: str = manifest["latest"]

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    platforms: dict[str, dict[str, str]] = {}
    for file_entry in manifest["files"]:
        nix_platform = platform_map.get((file_entry["os"], file_entry["arch"]))
        if nix_platform is not None:
            platforms[nix_platform] = {
                "url": file_entry["url"],
                "hash": hex_to_sri(file_entry["sha256"]),
            }

    missing = set(platform_map.values()) - set(platforms)
    if missing:
        msg = f"Missing platforms in manifest: {missing}"
        raise RuntimeError(msg)

    save_hashes(hashes_file, {"version": latest, "platforms": platforms})
    print(f"Updated to {latest}")
