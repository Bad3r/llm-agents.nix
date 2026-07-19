#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for zaly package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_npm_package

# The npm tarball ships without a lockfile; generate one (prod deps only,
# dist/ is prebuilt so dev deps are not needed).
update_npm_package(
    Path(__file__).parent,
    "@zaly/cli",
    ".#zaly",
    lockfile_env={"NPM_CONFIG_OMIT": "dev"},
)
