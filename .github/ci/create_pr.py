#!/usr/bin/env python3
"""Create or update a pull request for package/flake updates.

Environment variables:
  GH_TOKEN: GitHub token (required)
  PR_LABELS: Comma-separated list of labels (default: "dependencies,automated")
  AUTO_MERGE: Enable auto-merge (default: "false")
  CHANGELOG_URL: Changelog URL to include in commit body (optional)
"""

import argparse
import logging
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from lib import UpdateType, run

log = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PrConfig:
    """All the data needed to create a PR."""

    branch: str
    title: str
    body: str
    commit_message: str


def gh_get_pr_number(branch: str, repo_dir: Path) -> str | None:
    """Get the PR number for a branch, or None if no PR exists.

    Runs from the clean clone. The updater's checkout is untrusted.
    """
    result = run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--json",
            "number",
            "--jq",
            ".[0].number // empty",
        ],
        capture=True,
        cwd=str(repo_dir),
    )
    return result.stdout.strip() or None


def build_config(
    *,
    update_type: UpdateType,
    name: str,
    current_version: str,
    new_version: str,
    changelog_url: str,
) -> PrConfig:
    """Build branch, title, body, and commit message from update parameters."""
    match update_type:
        case UpdateType.PACKAGE:
            branch = f"update/{name}"
            title = f"{name}: {current_version} -> {new_version}"
            body = (
                f"Automated update of {name} from {current_version} to {new_version}."
            )
            commit_message = f"{title}\n\n{changelog_url}" if changelog_url else title

        case UpdateType.FLAKE_INPUT:
            branch = f"update-{name}"
            title = f"flake.lock: Update {name}"
            body = (
                f"This PR updates the flake input `{name}` to the latest version.\n\n"
                f"## Changes\n"
                f"- {name}: `{current_version}` → `{new_version}`"
            )
            commit_message = f"{title}\n\n{current_version} -> {new_version}"

    return PrConfig(
        branch=branch, title=title, body=body, commit_message=commit_message
    )


BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"


def git_ro(repo: Path, *args: str) -> str:
    """Run a read-only git command against the updater's (untrusted) repo.

    The updater could have planted hooks or config in that repo's .git,
    so disable the code-executing knobs and never push from it.
    """
    result = run(
        [
            "git",
            "-C",
            str(repo),
            "-c",
            "core.fsmonitor=false",
            "-c",
            "core.hooksPath=/dev/null",
            *args,
        ],
        capture=True,
    )
    return result.stdout


def allowed_roots(update_type: UpdateType, name: str) -> tuple[str, ...]:
    """Return the paths an update is allowed to touch."""
    match update_type:
        case UpdateType.PACKAGE:
            return (f"packages/{name}/",)
        case UpdateType.FLAKE_INPUT:
            return ("flake.lock",)


def changed_paths(repo: Path) -> list[str]:
    """List every work-tree path that differs from origin/main.

    Only the work tree matters: publishing copies files from it, so the
    index and branch commits are irrelevant.
    """
    tracked = git_ro(repo, "diff", "--name-only", "-z", "origin/main")
    untracked = git_ro(repo, "ls-files", "--others", "--exclude-standard", "-z")
    return sorted({p for p in (tracked + untracked).split("\0") if p})


def check_confinement(repo: Path, allowed: tuple[str, ...], name: str) -> None:
    """Abort if the (untrusted) updater changed files outside its territory."""
    stray = [p for p in changed_paths(repo) if not p.startswith(allowed)]
    if stray:
        log.error(
            "::error::update of %s changed files outside %s: %s",
            name,
            ", ".join(allowed),
            ", ".join(stray),
        )
        sys.exit(1)


def sync_path(src: Path, dst: Path) -> None:
    """Mirror one allowed file or directory from the dirty tree."""
    if dst.is_symlink() or dst.is_file():
        dst.unlink()
    elif dst.is_dir():
        shutil.rmtree(dst)
    if src.is_dir() and not src.is_symlink():
        shutil.copytree(src, dst, symlinks=True)
    elif src.is_symlink() or src.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst, follow_symlinks=False)


def clone_and_publish(config: PrConfig, allowed: tuple[str, ...]) -> Path:
    """Build the update branch in a pristine clone and push it.

    The updater had write access to the work tree and its .git, so that
    repo must never see the App token. Instead shallow-clone main afresh
    and copy over only the allowed paths.
    """
    dirty = Path.cwd()
    clean = Path(os.environ.get("RUNNER_TEMP") or tempfile.gettempdir()) / "clean-repo"
    if clean.exists():
        shutil.rmtree(clean)

    token = os.environ["GH_TOKEN"]
    repo_slug = os.environ["GITHUB_REPOSITORY"]
    url = f"https://x-access-token:{token}@github.com/{repo_slug}.git"

    def git(*args: str, check: bool = True) -> int:
        return run(["git", "-C", str(clean), *args], check=check).returncode

    run(["git", "clone", "--quiet", "--depth=1", "--branch", "main", url, str(clean)])
    git("config", "user.name", BOT_NAME)
    git("config", "user.email", BOT_EMAIL)
    git("checkout", "-q", "-B", config.branch)

    for rel in allowed:
        sync_path(dirty / rel, clean / rel)

    git("add", "--all", "--", *allowed)
    if git("diff", "--quiet", "--cached", check=False) != 0:
        git("commit", "-q", "-m", config.commit_message, "--signoff")
    git("push", "--force", "origin", f"HEAD:{config.branch}")
    return clean


def create_or_update_pr(
    config: PrConfig,
    *,
    update_type: UpdateType,
    name: str,
    labels: str,
    auto_merge: bool,
) -> None:
    """Verify confinement, publish the branch from a clean clone, open the PR.

    The work tree already carries manual fixups from any existing PR branch,
    rebased onto main by the workflow. Their content survives the copy,
    squashed into the update commit.
    """
    allowed = allowed_roots(update_type, name)
    check_confinement(Path.cwd(), allowed, name)
    clean = clone_and_publish(config, allowed)

    pr_number = gh_get_pr_number(config.branch, clean)

    if pr_number:
        log.info("Updating existing PR #%s", pr_number)
        run(
            [
                "gh",
                "pr",
                "edit",
                pr_number,
                "--title",
                config.title,
                "--body",
                config.body,
            ],
            cwd=str(clean),
        )
    else:
        log.info("Creating new PR")
        label_args: list[str] = [
            arg
            for raw in labels.split(",")
            if (stripped := raw.strip())
            for arg in ("--label", stripped)
        ]
        run(
            [
                "gh",
                "pr",
                "create",
                "--title",
                config.title,
                "--body",
                config.body,
                "--base",
                "main",
                "--head",
                config.branch,
                *label_args,
            ],
            cwd=str(clean),
        )
        pr_number = gh_get_pr_number(config.branch, clean)

    if auto_merge and pr_number:
        log.info("Enabling auto-merge for PR #%s", pr_number)
        run(
            ["gh", "pr", "merge", pr_number, "--auto", "--squash"],
            check=False,
            cwd=str(clean),
        )


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "type", choices=[t.value for t in UpdateType], help="update type"
    )
    parser.add_argument("name", help="package or flake input name")
    parser.add_argument("current_version", help="current version or revision")
    parser.add_argument("new_version", help="new version or revision")
    return parser.parse_args()


def main() -> None:
    """Create or update a PR for a package or flake-input update."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    if not os.environ.get("GH_TOKEN"):
        log.error("GH_TOKEN environment variable is not set")
        sys.exit(1)

    args = parse_args()
    update_type = UpdateType(args.type)
    config = build_config(
        update_type=update_type,
        name=args.name,
        current_version=args.current_version,
        new_version=args.new_version,
        changelog_url=os.environ.get("CHANGELOG_URL", ""),
    )
    create_or_update_pr(
        config,
        update_type=update_type,
        name=args.name,
        labels=os.environ.get("PR_LABELS", "dependencies,automated"),
        auto_merge=os.environ.get("AUTO_MERGE", "false") == "true",
    )


if __name__ == "__main__":
    main()
