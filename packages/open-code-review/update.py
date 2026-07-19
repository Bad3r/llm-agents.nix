#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for open-code-review package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_github_latest_release("alibaba", "open-code-review"),
    url_template="https://github.com/alibaba/open-code-review/releases/download/v{version}/opencodereview-{platform}",
    platforms={
        "x86_64-linux": "linux-amd64",
        "aarch64-linux": "linux-arm64",
        "x86_64-darwin": "darwin-amd64",
        "aarch64-darwin": "darwin-arm64",
    },
)
