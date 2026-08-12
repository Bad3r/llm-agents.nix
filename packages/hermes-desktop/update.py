#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Synchronise Desktop metadata with the currently pinned Hermes Agent tag."""

import subprocess
from pathlib import Path

AGENT_UPDATER = Path(__file__).parent.parent / "hermes-agent" / "update.py"

subprocess.run([AGENT_UPDATER, "--desktop-only"], check=True)
