#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nix-update --command python3

"""Update Hermes Agent and the desktop metadata coupled to its source tag.

The desktop application lives in the hermes-agent monorepo and shares the
agent's source and npm dependency derivation.  Its independent application
version must therefore be read from the same stable tag whenever the agent is
updated.  This wrapper deliberately resolves and validates that metadata
before allowing nix-update to write anything.
"""

import argparse
import json
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_github_latest_release, fetch_text, should_update
from updater.nix import nix_eval

PKG_DIR = Path(__file__).parent
DESKTOP_PACKAGE_NIX = PKG_DIR.parent / "hermes-desktop" / "package.nix"
OWNER = "NousResearch"
REPO = "hermes-agent"
STABLE_VERSION_RE = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
DESKTOP_VERSION_RE = re.compile(r'(desktopVersion = ")[^"]+(";)')


def fetch_desktop_version(agent_version: str) -> str:
    """Return the validated desktop version from an agent release tag."""
    if STABLE_VERSION_RE.fullmatch(agent_version) is None:
        msg = f"refusing non-stable Hermes Agent version: {agent_version!r}"
        raise ValueError(msg)

    url = (
        f"https://raw.githubusercontent.com/{OWNER}/{REPO}/"
        f"v{agent_version}/apps/desktop/package.json"
    )
    manifest: Any = json.loads(fetch_text(url))
    if not isinstance(manifest, dict):
        msg = f"v{agent_version} desktop package.json is not a JSON object"
        raise TypeError(msg)

    version = manifest.get("version")
    if not isinstance(version, str) or STABLE_VERSION_RE.fullmatch(version) is None:
        msg = (
            f"v{agent_version} desktop package.json has invalid stable version "
            f"{version!r}"
        )
        raise ValueError(msg)
    return version


def pinned_desktop_version() -> str:
    """Read the desktop version currently pinned in its Nix expression."""
    match = DESKTOP_VERSION_RE.search(DESKTOP_PACKAGE_NIX.read_text())
    if match is None:
        msg = f"could not find desktopVersion in {DESKTOP_PACKAGE_NIX}"
        raise ValueError(msg)
    return match.group(0).split('"')[1]


def pin_desktop_version(version: str) -> None:
    """Atomically replace the single desktopVersion pin."""
    text = DESKTOP_PACKAGE_NIX.read_text()
    updated, count = DESKTOP_VERSION_RE.subn(rf"\g<1>{version}\g<2>", text)
    if count != 1:
        msg = f"expected one desktopVersion in {DESKTOP_PACKAGE_NIX}, found {count}"
        raise ValueError(msg)

    # Keep readers from observing a truncated expression if this process is
    # interrupted while synchronising the coupled package.
    original_mode = stat.S_IMODE(DESKTOP_PACKAGE_NIX.stat().st_mode)
    with tempfile.NamedTemporaryFile(
        mode="w",
        dir=DESKTOP_PACKAGE_NIX.parent,
        prefix=f".{DESKTOP_PACKAGE_NIX.name}.",
        delete=False,
    ) as tmp:
        tmp.write(updated)
        tmp_path = Path(tmp.name)
    try:
        tmp_path.chmod(original_mode)
        tmp_path.replace(DESKTOP_PACKAGE_NIX)
    finally:
        tmp_path.unlink(missing_ok=True)


def main() -> None:
    """Update the shared tag or only repair its desktop version metadata."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--desktop-only",
        action="store_true",
        help="synchronise Desktop with the currently pinned Agent tag",
    )
    args = parser.parse_args()

    current = nix_eval(".#hermes-agent.version")
    if args.desktop_only:
        target = current
        bump = False
        print(f"Checking Hermes Desktop metadata from Agent v{current}")
    else:
        latest = fetch_github_latest_release(OWNER, REPO)
        bump = should_update(current, latest)
        target = latest if bump else current
        print(f"Current: {current}, Latest stable: {latest}")

    # Resolve all remote metadata before writing either coupled package.
    desktop_version = fetch_desktop_version(target)
    old_desktop_version = pinned_desktop_version()

    if bump:
        subprocess.run(
            [
                "nix-update",
                "--flake",
                "hermes-agent",
                "--version",
                target,
                "--subpackage",
                "hermes-frontend",
            ],
            check=True,
        )
    elif not args.desktop_only:
        print("Hermes Agent version already up to date")

    if desktop_version != old_desktop_version:
        print(
            f"Synchronising Hermes Desktop {old_desktop_version} -> "
            f"{desktop_version} from v{target}"
        )
        pin_desktop_version(desktop_version)
    else:
        print(f"Hermes Desktop already matches v{target} ({desktop_version})")


if __name__ == "__main__":
    main()
