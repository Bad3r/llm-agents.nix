"""Concrete purl handlers: one per upstream ecosystem.

``locations`` is pure and heavily tested; ``latest_version``/``source_hash``
take injected Deps so tests stay offline.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING, ClassVar
from urllib.parse import quote

from .fetch import (
    Deps,
    Location,
    MissingQualifierError,
    NoVersionFoundError,
    Resolved,
    VersionPolicy,
    as_dict,
    as_list,
    strip_tag_template,
    templated_locations,
)
from .hash import hex_to_sri

if TYPE_CHECKING:
    from .purl import Purl


class BaseHandler:
    """Shared dependency wiring and the default ``source_hash``."""

    purl_type: ClassVar[str] = ""

    def __init__(self, deps: Deps) -> None:
        """Store the injected network/hashing primitives."""
        self.deps = deps

    def source_hash(self, loc: Location) -> str:
        """SRI for one location: upstream checksum if present, else prefetch."""
        if loc.upstream_sha:
            return hex_to_sri(loc.upstream_sha)
        return self.deps.hash_url(loc.url, unpack=loc.unpack)

    def _select_ref(
        self, refs: list[str], template: str, policy: VersionPolicy, purl: Purl
    ) -> Resolved:
        """Strip refs to versions, let the policy choose, map the winner back."""
        pairs = [(strip_tag_template(ref, template), ref) for ref in refs]
        chosen = policy.select([version for version, _ in pairs])
        if chosen is None:
            msg = f"no version matched policy {policy.kind!r} for {purl}"
            raise NoVersionFoundError(msg)
        ref = next(ref for version, ref in pairs if version == chosen)
        return Resolved(version=chosen, ref=ref)


def _require_namespace(purl: Purl) -> str:
    """Return the purl's namespace or raise (github/gitea need an owner)."""
    if purl.namespace is None:
        msg = f"purl {purl} needs a namespace (owner)"
        raise NoVersionFoundError(msg)
    return purl.namespace


class GithubHandler(BaseHandler):
    """GitHub releases: source tarballs and release-asset matrices."""

    purl_type: ClassVar[str] = "github"

    def latest_version(self, purl: Purl, policy: VersionPolicy) -> Resolved:
        """Resolve the newest release tag under ``policy``."""
        owner, repo = _require_namespace(purl), purl.name
        template = purl.q("x_tag_template", "v{v}") or "v{v}"
        return self._select_ref(self._refs(owner, repo, policy), template, policy, purl)

    def _refs(self, owner: str, repo: str, policy: VersionPolicy) -> list[str]:
        """Return the candidate release tags: one for semver, the list otherwise."""
        base = f"https://api.github.com/repos/{owner}/{repo}"
        if policy.wants_candidate_list():
            items = as_list(self.deps.fetch_json(f"{base}/releases?per_page=100"))
            return [str(as_dict(item)["tag_name"]) for item in items]
        latest = as_dict(self.deps.fetch_json(f"{base}/releases/latest"))
        return [str(latest["tag_name"])]

    def locations(self, purl: Purl, resolved: Resolved) -> list[Location]:
        """Release-asset template if given, else the source tarball."""
        template = purl.q("x_download_url")
        if template:
            return templated_locations(purl, resolved, template)
        owner, repo = _require_namespace(purl), purl.name
        url = (
            f"https://github.com/{owner}/{repo}/archive/refs/tags/{resolved.ref}.tar.gz"
        )
        return [Location("src", url, unpack=True)]


class NpmHandler(BaseHandler):
    """npm registry: dist-tag versions and registry tarballs."""

    purl_type: ClassVar[str] = "npm"

    @staticmethod
    def _package(purl: Purl) -> str:
        """Return the full npm package name, e.g. ``@scope/name`` or ``name``."""
        return f"{purl.namespace}/{purl.name}" if purl.namespace else purl.name

    def latest_version(self, purl: Purl, policy: VersionPolicy) -> Resolved:
        """Read the version behind the requested dist-tag (default ``latest``)."""
        tag = purl.q("x_dist_tag", "latest") or "latest"
        encoded = quote(self._package(purl), safe="")
        data = as_dict(
            self.deps.fetch_json(f"https://registry.npmjs.org/{encoded}/{tag}")
        )
        version = str(data["version"])
        # dist-tag is a single pointer; policy is unused here (no choice to make).
        _ = policy
        return Resolved(version=version, ref=version)

    def locations(self, purl: Purl, resolved: Resolved) -> list[Location]:
        """Binary-split template if given, else the registry tarball."""
        template = purl.q("x_download_url")
        if template:
            return templated_locations(purl, resolved, template)
        package = self._package(purl)
        url = (
            f"https://registry.npmjs.org/{package}/-/{purl.name}-{resolved.version}.tgz"
        )
        return [Location("src", url, unpack=purl.q("x_unpack") == "true")]


class CargoHandler(BaseHandler):
    """crates.io: version discovery and ``.crate`` source archives."""

    purl_type: ClassVar[str] = "cargo"

    def latest_version(self, purl: Purl, policy: VersionPolicy) -> Resolved:
        """Pick the newest non-yanked crate version under ``policy``."""
        data = as_dict(
            self.deps.fetch_json(f"https://crates.io/api/v1/crates/{purl.name}")
        )
        versions = [
            str(as_dict(item)["num"])
            for item in as_list(data["versions"])
            if not as_dict(item).get("yanked")
        ]
        chosen = policy.select(versions)
        if chosen is None:
            msg = f"no version matched policy {policy.kind!r} for {purl}"
            raise NoVersionFoundError(msg)
        return Resolved(version=chosen, ref=chosen)

    def locations(self, purl: Purl, resolved: Resolved) -> list[Location]:
        """Return the canonical static.crates.io ``.crate`` tarball."""
        name = purl.name
        url = f"https://static.crates.io/crates/{name}/{name}-{resolved.version}.crate"
        return [Location("src", url, unpack=True)]


class GiteaHandler(BaseHandler):
    """Self-hosted Gitea/Forgejo: needs an ``x_host`` qualifier."""

    purl_type: ClassVar[str] = "gitea"

    @staticmethod
    def _host(purl: Purl) -> str:
        """Return the Gitea instance base URL from ``x_host`` (trailing slash stripped)."""
        host = purl.q("x_host")
        if not host:
            key = "x_host"
            raise MissingQualifierError(key, purl)
        return host.rstrip("/")

    def latest_version(self, purl: Purl, policy: VersionPolicy) -> Resolved:
        """Resolve the newest release tag on the Gitea instance."""
        host = self._host(purl)
        owner, repo = _require_namespace(purl), purl.name
        template = purl.q("x_tag_template", "v{v}") or "v{v}"
        data = as_list(
            self.deps.fetch_json(
                f"{host}/api/v1/repos/{owner}/{repo}/releases?limit=50"
            )
        )
        refs = [str(as_dict(item)["tag_name"]) for item in data]
        return self._select_ref(refs, template, policy, purl)

    def locations(self, purl: Purl, resolved: Resolved) -> list[Location]:
        """Release-asset template if given, else the Gitea archive tarball."""
        template = purl.q("x_download_url")
        if template:
            return templated_locations(purl, resolved, template)
        host = self._host(purl)
        owner, repo = _require_namespace(purl), purl.name
        url = f"{host}/{owner}/{repo}/archive/{resolved.ref}.tar.gz"
        return [Location("src", url, unpack=True)]


class GenericHandler(BaseHandler):
    """Arbitrary hosts driven by qualifiers (CDNs, pointer files).

    Covers the text-pointer case (``x_version_url`` + ``x_version_regex``).
    Richer modes (JSON manifests, checksum files) are left to per-package hooks.
    """

    purl_type: ClassVar[str] = "generic"

    def latest_version(self, purl: Purl, policy: VersionPolicy) -> Resolved:
        """Scrape the version from a pointer URL with a regex."""
        version_url = purl.q("x_version_url")
        pattern = purl.q("x_version_regex")
        if not version_url or not pattern:
            msg = (
                f"generic purl {purl} needs x_version_url and x_version_regex; "
                "other generic modes require a per-package hook"
            )
            raise NoVersionFoundError(msg)
        text = self.deps.fetch_text(version_url)
        match = re.search(pattern, text)
        if not match:
            msg = f"pattern {pattern!r} did not match at {version_url}"
            raise NoVersionFoundError(msg)
        version = match.group(1) if match.groups() else match.group(0)
        _ = policy
        return Resolved(version=version, ref=version)

    def locations(self, purl: Purl, resolved: Resolved) -> list[Location]:
        """Build locations from the required ``x_download_url`` template."""
        template = purl.q("x_download_url")
        if not template:
            key = "x_download_url"
            raise MissingQualifierError(key, purl)
        return templated_locations(purl, resolved, template)
