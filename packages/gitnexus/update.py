#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nix-update --command python3

"""Update script for gitnexus.

Upstream publishes a steady stream of release-candidate tags
(v1.6.6-rc.NNN). nix-update reads only the most recent releases from the
GitHub feed, so once the latest stable tag falls off that page its version
regex matches nothing and the update job fails. Query the GitHub
"latest release" endpoint instead, which already excludes prereleases, and
hand the exact version to nix-update.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, should_update
from updater.nix import nix_eval


def main() -> None:
    """Update gitnexus to the latest stable release."""
    current = nix_eval(".#gitnexus.version")
    latest = fetch_github_latest_release("abhigyanpatwari", "GitNexus")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    subprocess.run(
        ["nix-update", "--flake", "gitnexus", "--version", latest],
        check=True,
    )


if __name__ == "__main__":
    main()
