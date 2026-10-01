#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nix-update --command python3

"""Update Hermes Agent and its vendored nemo-relay.

The vendored nemo-relay build is bumped to the newest upstream tag that
satisfies the agent's pyproject constraint, since upstream raises the lower
bound regularly.
"""

import re
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    fetch_github_latest_release,
    fetch_json,
    fetch_text,
    should_update,
)
from updater.nix import nix_eval
from updater.version import compare_versions

OWNER = "NousResearch"
REPO = "hermes-agent"
NEMO_RELAY_OWNER = "NVIDIA"
NEMO_RELAY_REPO = "NeMo-Relay"
STABLE_VERSION_RE = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")


NEMO_RELAY_REQ_RE = re.compile(r"nemo-relay\s*([<>=!,.\d\s]+)")
SPEC_RE = re.compile(r"(>=|<=|==|<|>)\s*([\d.]+)")
SPEC_OPS = {
    ">=": lambda c: c >= 0,
    "<=": lambda c: c <= 0,
    "==": lambda c: c == 0,
    ">": lambda c: c > 0,
    "<": lambda c: c < 0,
}


def fetch_nemo_relay_spec(agent_version: str) -> list[tuple[str, str]]:
    """Return the nemo-relay (op, version) constraints from pyproject.toml."""
    url = (
        f"https://raw.githubusercontent.com/{OWNER}/{REPO}/"
        f"v{agent_version}/pyproject.toml"
    )
    pyproject = tomllib.loads(fetch_text(url))
    for dep in pyproject["project"]["dependencies"]:
        m = NEMO_RELAY_REQ_RE.match(dep)
        if m:
            return SPEC_RE.findall(m.group(1))
    msg = f"v{agent_version} pyproject.toml has no nemo-relay dependency"
    raise ValueError(msg)


def satisfies(version: str, spec: list[tuple[str, str]]) -> bool:
    """Check a version against simple comparison constraints."""
    return all(SPEC_OPS[op](compare_versions(version, bound)) for op, bound in spec)


def resolve_nemo_relay_version(spec: list[tuple[str, str]]) -> str:
    """Pick the newest stable NeMo-Relay tag satisfying ``spec``."""
    tags: Any = fetch_json(
        f"https://api.github.com/repos/{NEMO_RELAY_OWNER}/{NEMO_RELAY_REPO}"
        "/tags?per_page=100"
    )
    candidates: list[str] = [
        t["name"]
        for t in tags
        if STABLE_VERSION_RE.fullmatch(t["name"]) and satisfies(t["name"], spec)
    ]
    if not candidates:
        msg = f"no {NEMO_RELAY_REPO} tag satisfies {spec}"
        raise ValueError(msg)
    best = candidates[0]
    for c in candidates[1:]:
        if compare_versions(c, best) > 0:
            best = c
    return best


def update_nemo_relay(agent_version: str) -> None:
    """Bump the vendored nemo-relay if the agent's constraint demands it."""
    spec = fetch_nemo_relay_spec(agent_version)
    current = nix_eval(".#hermes-agent.nemo-relay.version")
    target = resolve_nemo_relay_version(spec)
    print(f"nemo-relay: current {current}, target {target} {spec}")
    if not should_update(current, target):
        return
    subprocess.run(
        ["nix-update", "--flake", "hermes-agent.nemo-relay", "--version", target],
        check=True,
    )


def main() -> None:
    """Update the agent to the latest stable release."""
    current = nix_eval(".#hermes-agent.version")
    latest = fetch_github_latest_release(OWNER, REPO)
    print(f"Current: {current}, Latest stable: {latest}")

    if should_update(current, latest):
        subprocess.run(
            [
                "nix-update",
                "--flake",
                "hermes-agent",
                "--version",
                latest,
                "--subpackage",
                "hermes-frontend",
            ],
            check=True,
        )
        current = latest

    update_nemo_relay(current)


if __name__ == "__main__":
    main()
