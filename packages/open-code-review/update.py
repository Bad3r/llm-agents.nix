#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for open-code-review package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"

PLATFORMS = {
    "x86_64-linux": "linux-amd64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-amd64",
    "aarch64-darwin": "darwin-arm64",
}


def main() -> None:
    """Update the open-code-review package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("alibaba", "open-code-review")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url_template = f"https://github.com/alibaba/open-code-review/releases/download/v{latest}/opencodereview-{{platform}}"
    hashes = calculate_platform_hashes(url_template, PLATFORMS)

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
