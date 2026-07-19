#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for pi package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_npm_package

update_npm_package(
    Path(__file__).parent,
    "@earendil-works/pi-coding-agent",
    ".#pi",
)
