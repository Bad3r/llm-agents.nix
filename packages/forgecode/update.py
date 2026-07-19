#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for forgecode package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_github_latest_release("tailcallhq", "forgecode"),
    url_template="https://github.com/tailcallhq/forgecode/releases/download/v{version}/forge-{platform}",
    platforms={
        "x86_64-linux": "x86_64-unknown-linux-gnu",
        "aarch64-linux": "aarch64-unknown-linux-gnu",
        "x86_64-darwin": "x86_64-apple-darwin",
        "aarch64-darwin": "aarch64-apple-darwin",
    },
)
