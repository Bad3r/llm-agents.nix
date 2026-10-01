#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Pin desktopVersion to the one shipped in the pinned Hermes Agent tag."""

import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_json
from updater.nix import nix_eval

PACKAGE_NIX = Path(__file__).parent / "package.nix"

tag = f"v{nix_eval('.#hermes-agent.version')}"
manifest: Any = fetch_json(
    "https://raw.githubusercontent.com/NousResearch/hermes-agent/"
    f"{tag}/apps/desktop/package.json"
)
version = manifest["version"]
# It is spliced into a Nix string below.
if not re.fullmatch(r"[0-9.]+", version):
    sys.exit(f"unexpected desktop version {version!r} in {tag}")

text, count = re.subn(
    r'(desktopVersion = ")[^"]+', rf"\g<1>{version}", PACKAGE_NIX.read_text()
)
if count != 1:
    sys.exit(f"expected one desktopVersion in {PACKAGE_NIX}, found {count}")
PACKAGE_NIX.write_text(text)
print(f"Hermes Desktop {version} from {tag}")
