"""Update flow for packages that repackage prebuilt per-platform binaries."""

from __future__ import annotations

from typing import TYPE_CHECKING

from updater.hashes_file import load_hashes, save_hashes
from updater.platforms import calculate_platform_hashes
from updater.version import should_update

if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path


def update_platform_binaries(
    pkg_dir: Path,
    *,
    fetch_latest: Callable[[], str],
    url_template: str,
    platforms: dict[str, str],
) -> None:
    """Update a package that repackages prebuilt per-platform binaries.

    ``url_template`` may use ``{version}`` and ``{platform}`` placeholders.
    """
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]
    latest = fetch_latest()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    hashes = calculate_platform_hashes(url_template, platforms, version=latest)

    save_hashes(hashes_file, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")
