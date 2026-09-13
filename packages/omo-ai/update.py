#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update omo-ai (npm beta dist-tag) and its pinned senpi engine."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_json,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES = Path(__file__).parent / "hashes.json"


def tarball(name: str, version: str) -> str:
    """Registry tarball URL for a (possibly scoped) package."""
    return (
        f"https://registry.npmjs.org/{name}/-/{name.rpartition('/')[2]}-{version}.tgz"
    )


def main() -> None:
    """Bump omo-ai to the beta dist-tag and follow its senpi pin."""
    data = load_hashes(HASHES)
    latest = fetch_npm_version("omo-ai", tag="beta")
    print(f"Current: {data['version']}, Latest: {latest}")
    if not should_update(data["version"], latest):
        print("Already up to date")
        return

    manifest = dict(fetch_json(f"https://registry.npmjs.org/omo-ai/{latest}"))
    senpi = manifest["dependencies"]["@code-yeongyu/senpi"]
    save_hashes(
        HASHES,
        {
            "version": latest,
            "hash": calculate_url_hash(tarball("omo-ai", latest)),
            "senpiVersion": senpi,
            "senpiHash": calculate_url_hash(tarball("@code-yeongyu/senpi", senpi)),
        },
    )
    print(f"Updated to {latest} (senpi {senpi})")


if __name__ == "__main__":
    main()
