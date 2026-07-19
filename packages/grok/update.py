#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for grok package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_text, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_text(
        "https://storage.googleapis.com/grok-build-public-artifacts/cli/stable"
    ).strip(),
    url_template="https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-{version}-{platform}",
    platforms={
        "x86_64-linux": "linux-x86_64",
        "aarch64-linux": "linux-aarch64",
        "aarch64-darwin": "macos-aarch64",
    },
)
