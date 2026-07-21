#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cubic package (prebuilt binaries)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_text, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_text(
        "https://mcafvrhahbqdwfrtncql.supabase.co/storage/v1/object/public/releases/latest.txt"
    ).strip(),
    url_template="https://mcafvrhahbqdwfrtncql.supabase.co/storage/v1/object/public/releases/v{version}/cubic-{platform}.zip",
    platforms={
        "x86_64-linux": "linux-x64",
        "aarch64-linux": "linux-arm64",
        "aarch64-darwin": "darwin-arm64",
    },
)
