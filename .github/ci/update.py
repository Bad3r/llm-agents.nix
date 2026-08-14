#!/usr/bin/env python3
"""Perform updates for packages or flake inputs.

Outputs (written to GITHUB_OUTPUT):
  updated: "true" or "false"
  new_version: the new version string
  changelog: the changelog URL (packages only)
"""

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

from lib import UpdateType, nix_eval_raw, run, write_output

log = logging.getLogger(__name__)


def sandbox_works(bwrap: str) -> bool:
    """Probe whether bubblewrap can create its namespaces here."""
    probe = [bwrap, "--ro-bind", "/", "/", "--", "true"]
    if run(probe, check=False, capture=True).returncode == 0:
        return True
    # Ubuntu 24.04 runners restrict unprivileged user namespaces via
    # AppArmor. The runner user has passwordless sudo, so lift the limit.
    if shutil.which("sudo"):
        run(
            ["sudo", "sysctl", "-w", "kernel.apparmor_restrict_unprivileged_userns=0"],
            check=False,
            capture=True,
        )
    return run(probe, check=False, capture=True).returncode == 0


def sandbox_wrap(cmd: list[str], name: str) -> list[str]:
    """Confine updater code with bubblewrap.

    The filesystem is read-only except the package's own directory, /nix,
    and a fresh tmpfs HOME and /tmp. Network stays available for upstream
    APIs. Set UPDATE_SANDBOX=0 to opt out locally.
    """
    if sys.platform != "linux" or os.environ.get("UPDATE_SANDBOX") == "0":
        return cmd
    bwrap = shutil.which("bwrap")
    if bwrap is None:
        log.warning("::warning::bwrap not found; running updater unsandboxed")
        return cmd
    if not sandbox_works(bwrap):
        log.warning(
            "::warning::bubblewrap cannot create namespaces; "
            "running updater unsandboxed"
        )
        return cmd
    pkg_dir = str(Path.cwd() / "packages" / name)
    # Fresh HOME instead of a tmpfs over the real one, which would hide
    # ~/.nix-profile/bin. Later binds override the read-only root.
    return [
        bwrap,
        *("--ro-bind", "/", "/"),
        *("--dev", "/dev"),
        *("--proc", "/proc"),
        *("--tmpfs", "/tmp"),  # noqa: S108 — sandbox mount, not a host temp path
        *("--dir", "/tmp/home"),  # noqa: S108
        *("--setenv", "HOME", "/tmp/home"),  # noqa: S108
        *("--setenv", "TMPDIR", "/tmp"),  # noqa: S108
        *("--bind", "/nix", "/nix"),
        *("--bind", pkg_dir, pkg_dir),
        *("--chdir", str(Path.cwd())),
        "--die-with-parent",
        "--",
        *cmd,
    ]


def git_has_changes() -> bool:
    """Check if the branch differs from origin/main.

    Diffing against origin/main also catches commits already on a reused
    update/* branch that never made it into a pull request.
    """
    return run(["git", "diff", "--quiet", "origin/main"], check=False).returncode != 0


def run_update_command(cmd: list[str], error_label: str) -> None:
    """Run an update command, streaming merged stdout+stderr, and exit on failure."""
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.returncode != 0:
        log.error("::error::%s", error_label)
        sys.exit(1)


def load_nix_update_args(name: str) -> list[str]:
    """Load extra nix-update arguments from the package's nix-update-args file."""
    args_file = Path(f"packages/{name}/nix-update-args")
    if not args_file.exists():
        return []
    log.info("Loading nix-update args from %s", args_file)
    return [
        stripped
        for line in args_file.read_text().splitlines()
        if (stripped := line.strip()) and not stripped.startswith("#")
    ]


def update_package(name: str) -> None:
    """Update a single package using its update script or nix-update."""
    log.info("Updating package %s...", name)

    update_script = Path(f"packages/{name}/update.py")
    if update_script.exists():
        log.info("Running update script for %s...", name)
        run_update_command(
            sandbox_wrap([str(update_script)], name),
            f"Update script failed for package {name}",
        )
    else:
        log.info("No update script found, trying nix-update...")
        run_update_command(
            sandbox_wrap(
                ["nix-update", "--flake", name, *load_nix_update_args(name)], name
            ),
            f"nix-update failed for package {name}",
        )

    if not git_has_changes():
        log.info("No changes detected")
        write_output("updated", "false")
        return

    attr = f".#packages.x86_64-linux.{name}"
    new_version = nix_eval_raw(f"{attr}.version") or "unknown"
    log.info("New version: %s", new_version)

    changelog = nix_eval_raw(f"{attr}.meta.changelog") or ""
    if not changelog:
        log.warning("::warning::Package %s is missing meta.changelog", name)

    write_output("updated", "true")
    write_output("new_version", new_version)
    write_output("changelog", changelog)


def update_flake_input(name: str) -> None:
    """Update a single flake input."""
    log.info("Updating input %s...", name)

    if run(["nix", "flake", "update", name], check=False).returncode != 0:
        log.error("::error::Failed to update %s", name)
        sys.exit(1)

    if not git_has_changes():
        log.info("No changes detected")
        write_output("updated", "false")
        return

    metadata_result = run(
        ["nix", "flake", "metadata", "--json", "--no-write-lock-file"],
        capture=True,
    )
    metadata = json.loads(metadata_result.stdout)
    rev: str = (
        metadata.get("locks", {})
        .get("nodes", {})
        .get(name, {})
        .get("locked", {})
        .get("rev", "unknown")
    )
    new_rev = rev[:8]
    log.info("New revision: %s", new_rev)

    write_output("updated", "true")
    write_output("new_version", new_rev)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "type", choices=[t.value for t in UpdateType], help="update type"
    )
    parser.add_argument("name", help="package or flake input name")
    return parser.parse_args()


def main() -> None:
    """Entry point: dispatch to package or flake-input updater."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    args = parse_args()
    os.environ["NIX_PATH"] = "nixpkgs=flake:nixpkgs"

    match UpdateType(args.type):
        case UpdateType.PACKAGE:
            update_package(args.name)
        case UpdateType.FLAKE_INPUT:
            update_flake_input(args.name)


if __name__ == "__main__":
    main()
