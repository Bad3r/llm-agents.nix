#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for catnip package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_github_latest_release("wandb", "catnip"),
    url_template="https://github.com/wandb/catnip/releases/download/v{version}/catnip_{version}_{platform}.tar.gz",
    platforms={
        "x86_64-linux": "linux_amd64",
        "aarch64-linux": "linux_arm64",
        "aarch64-darwin": "darwin_arm64",
    },
)
