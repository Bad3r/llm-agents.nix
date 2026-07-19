"""High-level update flows shared by packages/*/update.py scripts.

Each module implements one common update pattern (npm tarball, GitHub source
tarball with a dependency hash, prebuilt platform binaries, bun2nix) so that
per-package update scripts only need to supply their configuration.
"""

from .bun_github import update_bun_github
from .github_source import update_github_source
from .npm_package import update_npm_package
from .platform_binaries import update_platform_binaries

__all__ = [
    "update_bun_github",
    "update_github_source",
    "update_npm_package",
    "update_platform_binaries",
]
