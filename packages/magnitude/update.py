#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update Magnitude from the release manifest published with each CLI tag."""

import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_json, load_hashes, save_hashes, should_update
from updater.hash import hex_to_sri

HASHES_FILE = Path(__file__).parent / "hashes.json"
REPO = "magnitudedev/magnitude"
TAG_PREFIX = "@magnitudedev/cli@"

# nix system -> (manifest host, Debian architecture)
PLATFORMS = {
    "x86_64-linux": ("linux-x64-gnu", "amd64"),
    "aarch64-linux": ("linux-arm64-gnu", "arm64"),
}


def fetch_object(url: str) -> dict[str, Any]:
    """Fetch a URL that must return a JSON object."""
    data = fetch_json(url)
    if not isinstance(data, dict):
        msg = f"expected a JSON object from {url}"
        raise TypeError(msg)
    return data


def latest_version() -> str:
    """Read the version from the latest non-prerelease CLI tag."""
    release = fetch_object(f"https://api.github.com/repos/{REPO}/releases/latest")
    tag = release["tag_name"]
    match = re.fullmatch(re.escape(TAG_PREFIX) + r"([0-9]+\.[0-9]+\.[0-9]+)", tag)
    if not match:
        msg = f"unexpected release tag {tag!r}"
        raise ValueError(msg)
    return match.group(1)


def artifact_hash(manifest: dict[str, Any], kind: str, host: str, filename: str) -> str:
    """Return the SRI hash of the one manifest artifact with this filename."""
    matches = [
        artifact
        for artifact in manifest["artifacts"]
        if artifact["kind"] == kind
        and artifact["host"] == host
        and artifact["filename"] == filename
    ]
    if len(matches) != 1:
        msg = (
            f"expected one {kind} artifact {filename} for {host}, found {len(matches)}"
        )
        raise ValueError(msg)
    return hex_to_sri(matches[0]["sha256"])


def main() -> None:
    """Update the magnitude package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = latest_version()

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = quote(f"{TAG_PREFIX}{latest}", safe="/")
    manifest = fetch_object(
        f"https://github.com/{REPO}/releases/download/{tag}/magnitude-release.json"
    )
    if manifest["version"] != latest:
        msg = f"manifest version {manifest['version']!r} does not match {latest!r}"
        raise ValueError(msg)
    # The deb filename carries the release's ACN revision.
    revision = manifest["acnRevision"]

    desktop: dict[str, str] = {}
    inference: dict[str, str] = {}
    for system, (host, deb_arch) in PLATFORMS.items():
        desktop[system] = artifact_hash(
            manifest,
            "desktop",
            host,
            f"magnitude-desktop_{latest}-{revision}_{deb_arch}.deb",
        )
        inference[system] = artifact_hash(
            manifest, "icn-base", host, f"magnitude-icn-base-{host}.tar.gz"
        )
        print(f"  {system}: {desktop[system]} {inference[system]}")

    save_hashes(
        HASHES_FILE,
        {
            "version": latest,
            "revision": revision,
            "desktop": desktop,
            "inference": inference,
        },
    )
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
