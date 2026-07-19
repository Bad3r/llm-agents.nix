#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#bun nixpkgs#git --command python3

"""Update script for qmd package.

Custom updater needed because qmd uses bun2nix: after each version bump the
bun.nix lockfile must be regenerated from the upstream bun.lock.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_bun_github

update_bun_github(
    Path(__file__).parent,
    "tobi",
    "qmd",
)
