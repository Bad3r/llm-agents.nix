#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for codex package.

The package builds the releases of Bad3r/codex, which are upstream releases,
prereleases included, plus a patch stack, tagged
patched-v<upstream version>-r<revision>. This script updates fork.json to the
newest one, including the librusty_v8 hashes.
The v8 version is extracted from the Cargo.lock file of the release.
"""

import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_version_from_text,
    load_hashes,
    save_hashes,
    should_update,
    update_dependency_hash,
)
from updater.hash import DUMMY_SHA256_HASH

HASHES_FILE = Path(__file__).parent / "fork.json"

FORK_TAG = r"patched-v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)-r(\d+)"

RUSTY_V8_PLATFORMS = {
    "x86_64-linux": "x86_64-unknown-linux-gnu",
    "aarch64-linux": "aarch64-unknown-linux-gnu",
    "aarch64-darwin": "aarch64-apple-darwin",
}


def fetch_release() -> tuple[str, int]:
    """Fetch the upstream version and revision of the newest fork release."""
    tag = fetch_github_latest_release("Bad3r", "codex", tag_pattern=FORK_TAG)
    match = re.fullmatch(FORK_TAG, tag)
    if not match:
        msg = f"Unexpected tag format: {tag!r}, expected 'patched-v<version>-r<N>'"
        raise ValueError(msg)
    return match.group(1), int(match.group(2))


def is_newer(current: tuple[str, int], latest: tuple[str, int]) -> bool:
    """Order releases by upstream version, then by revision."""
    if current[0] == latest[0]:
        return current[1] < latest[1]
    return should_update(current[0], latest[0])


def librusty_v8_pins(tag: str, previous: dict[str, Any] | None) -> dict[str, Any]:
    """Return the librusty_v8 pin for the given fork release tag.

    Re-uses existing hashes when the v8 version has not changed to avoid
    re-downloading four ~100MB archives on every bump.
    """
    v8_version = fetch_version_from_text(
        f"https://raw.githubusercontent.com/Bad3r/codex/{tag}/codex-rs/Cargo.lock",
        r'name = "v8"\nversion = "([^"]+)"',
    )
    print(f"V8 version: {v8_version}")

    if previous and previous.get("version") == v8_version:
        print("V8 unchanged, reusing hashes")
        return previous

    # denoland publishes no prebuilts for the v8_enable_sandbox combo codex
    # uses; openai releases their own under the rusty-v8-v<version> tag.
    # Mirrors .github/actions/setup-rusty-v8 in the codex repo.
    profile = "ptrcomp_sandbox_release"
    base_url = (
        f"https://github.com/openai/codex/releases/download/rusty-v8-v{v8_version}"
    )
    hashes = calculate_platform_hashes(
        base_url + "/librusty_v8_" + profile + "_{platform}.a.gz",
        RUSTY_V8_PLATFORMS,
    )
    binding_hashes = calculate_platform_hashes(
        base_url + "/src_binding_" + profile + "_{platform}.rs",
        RUSTY_V8_PLATFORMS,
    )
    return {
        "version": v8_version,
        "profile": profile,
        "baseUrl": base_url,
        "hashes": {k: hashes[k] for k in RUSTY_V8_PLATFORMS},
        "srcBindingHashes": {k: binding_hashes[k] for k in RUSTY_V8_PLATFORMS},
    }


def main() -> None:
    """Update the codex package."""
    data = load_hashes(HASHES_FILE)
    current = (data["version"], data["revision"])
    latest = fetch_release()

    print(f"Current: {current[0]}-r{current[1]}, Latest: {latest[0]}-r{latest[1]}")

    if not is_newer(current, latest):
        print("Already up to date")
        return

    version, revision = latest
    tag = f"patched-v{version}-r{revision}"
    url = f"https://github.com/Bad3r/codex/archive/refs/tags/{tag}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": version,
        "revision": revision,
        "hash": source_hash,
        "cargoHash": DUMMY_SHA256_HASH,
        "librusty_v8": librusty_v8_pins(tag, data.get("librusty_v8")),
    }
    save_hashes(HASHES_FILE, data)

    update_dependency_hash(".#codex", "cargoHash", HASHES_FILE, data)

    print(f"Updated to {version}-r{revision}")


if __name__ == "__main__":
    main()
