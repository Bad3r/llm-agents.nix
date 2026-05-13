#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for herdr package.

On Linux herdr builds from source (Rust + zig for vendored libghostty-vt).
On Darwin we use upstream release binaries because zig's macOS SDK
discovery does not work in the Nix sandbox yet.  Updates therefore touch
the source hash, cargoHash, and the per-platform Darwin binary hashes.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_dependency_hash,
    calculate_platform_hashes,
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)
from updater.nix import NixCommandError

HASHES_FILE = Path(__file__).parent / "hashes.json"

OWNER = "ogulcancelik"
REPO = "herdr"

DARWIN_PLATFORMS = {
    "aarch64-darwin": "macos-aarch64",
    "x86_64-darwin": "macos-x86_64",
}


def main() -> None:
    """Update the herdr package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating herdr from {current} to {latest}")

    src_url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/v{latest}.tar.gz"
    bin_url = (
        f"https://github.com/{OWNER}/{REPO}/releases/download/v{latest}/"
        "herdr-{platform}"
    )

    data["version"] = latest
    data["hash"] = calculate_url_hash(src_url, unpack=True)
    data["binaryHashes"] = calculate_platform_hashes(bin_url, DARWIN_PLATFORMS)
    save_hashes(HASHES_FILE, data)

    try:
        data["cargoHash"] = calculate_dependency_hash(
            ".#herdr",
            "cargoHash",
            HASHES_FILE,
            data,
        )
        save_hashes(HASHES_FILE, data)
    except (ValueError, NixCommandError) as e:
        print(f"Error: {e}")
        return

    print(f"Updated herdr to {latest}")


if __name__ == "__main__":
    main()
