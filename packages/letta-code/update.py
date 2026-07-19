#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for letta-code package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_npm_package

# Use legacy-peer-deps to resolve ink version conflicts (ink-link requires >=6,
# but the package uses ^5).
update_npm_package(
    Path(__file__).parent,
    "@letta-ai/letta-code",
    ".#letta-code",
    lockfile_env={"NPM_CONFIG_LEGACY_PEER_DEPS": "true"},
)
