"""Update flow for packages whose upstream ships a JSON manifest of binaries."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.fetch import Location, default_deps
from updater.handlers import GenericHandler
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

    The manifest needs ``latest`` and a ``files`` list of ``os``/``arch``/
    ``url``/``sha256`` (hex). ``platform_map`` maps ``(os, arch)`` to Nix
    platform names. The exact URL is recorded, not reconstructed: upstream has
    changed file naming before. Each file goes through ``Location`` so the
    hex-to-SRI conversion reuses the shared ``source_hash`` path.
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

    hasher = GenericHandler(default_deps())
    platforms: dict[str, dict[str, str]] = {}
    for file_entry in manifest["files"]:
        nix_platform = platform_map.get((file_entry["os"], file_entry["arch"]))
        if nix_platform is not None:
            location = Location(
                nix_platform, file_entry["url"], upstream_sha=file_entry["sha256"]
            )
            platforms[nix_platform] = {
                "url": location.url,
                "hash": hasher.source_hash(location),
            }

    missing = set(platform_map.values()) - set(platforms)
    if missing:
        msg = f"Missing platforms in manifest: {missing}"
        raise RuntimeError(msg)

    save_hashes(hashes_file, {"version": latest, "platforms": platforms})
    print(f"Updated to {latest}")
