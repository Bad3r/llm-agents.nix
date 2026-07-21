#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for opencode package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_github_latest_release("anomalyco", "opencode"),
    url_template="https://github.com/anomalyco/opencode/releases/download/v{version}/{platform}",
    platforms={
        "x86_64-linux": "opencode-linux-x64.tar.gz",
        "aarch64-linux": "opencode-linux-arm64.tar.gz",
        "aarch64-darwin": "opencode-darwin-arm64.zip",
    },
)
