#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for crush package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_github_source

update_github_source(
    Path(__file__).parent,
    "charmbracelet",
    "crush",
    ".#crush",
    "vendorHash",
)
