#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update the Swamp package from the project's official artifact service."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
TAGS_API = "https://git.swamp-club.com/api/v1/repos/swamp-club/swamp/tags?limit=50"
PLATFORMS = {
    "x86_64-linux": ("linux", "x86_64"),
    "aarch64-linux": ("linux", "aarch64"),
    "aarch64-darwin": ("darwin", "aarch64"),
}


def main() -> None:
    """Update the version and hashes for all supported platforms."""
    current = load_hashes(HASHES_FILE)["version"]
    tags = fetch_json(TAGS_API)
    if not isinstance(tags, list):
        msg = f"Expected a list of tags, got {type(tags)}"
        raise TypeError(msg)
    latest = max(tag["name"].removeprefix("v") for tag in tags)

    print(f"Current: {current}, Latest: {latest}")
    if not should_update(current, latest):
        print("Already up to date")
        return

    hashes = calculate_platform_hashes(
        "https://artifacts.swamp-club.com/swamp/{version}/binary/{platform}.tar.gz",
        {
            system: f"{os}/{cpu}/swamp-{latest}-binary-{os}-{cpu}"
            for system, (os, cpu) in PLATFORMS.items()
        },
        version=latest,
    )

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
